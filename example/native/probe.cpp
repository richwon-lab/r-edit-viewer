// 실험 전용 DirectWrite 묶음 경계. font parser/renderer를 구현하지 않는다.
#include <windows.h>
#include <d2d1.h>
#include <dwrite.h>
#include <wrl/client.h>
#include <vector>
#include <string>
#include <sstream>
#include <iomanip>
#include <chrono>
#include <stdexcept>
#include <mutex>
using Microsoft::WRL::ComPtr;
using Clock = std::chrono::steady_clock;
static double ms(Clock::time_point t) {
  return std::chrono::duration<double, std::milli>(Clock::now() - t).count();
}
struct Failure : std::runtime_error {
  HRESULT hr;
  Failure(const char *s, HRESULT h) : runtime_error(s), hr(h) {}
};
static void check(HRESULT h, const char *stage) {
  if (FAILED(h))
    throw Failure(stage, h);
}
struct Run {
  UINT32 start, len;
  DWRITE_SCRIPT_ANALYSIS script;
};
// 분석 source/sink는 호출 내부 소유. 원문은 그대로, 지원 범위는 LTR
// ASCII/완성형 한글이다.
struct Analysis : IDWriteTextAnalysisSource, IDWriteTextAnalysisSink {
  std::wstring text;
  std::vector<Run> runs;
  explicit Analysis(std::wstring t) : text(std::move(t)) {}
  HRESULT STDMETHODCALLTYPE QueryInterface(REFIID id, void **p) override {
    if (id == __uuidof(IUnknown) || id == __uuidof(IDWriteTextAnalysisSource))
      *p = static_cast<IDWriteTextAnalysisSource *>(this);
    else if (id == __uuidof(IDWriteTextAnalysisSink))
      *p = static_cast<IDWriteTextAnalysisSink *>(this);
    else {
      *p = nullptr;
      return E_NOINTERFACE;
    }
    AddRef();
    return S_OK;
  }
  ULONG STDMETHODCALLTYPE AddRef() override { return 1; }
  ULONG STDMETHODCALLTYPE Release() override { return 1; }
  HRESULT STDMETHODCALLTYPE GetTextAtPosition(UINT32 p, const WCHAR **s,
                                              UINT32 *n) override {
    *s = p < text.size() ? text.data() + p : nullptr;
    *n = p < text.size() ? UINT32(text.size() - p) : 0;
    return S_OK;
  }
  HRESULT STDMETHODCALLTYPE GetTextBeforePosition(UINT32 p, const WCHAR **s,
                                                  UINT32 *n) override {
    *s = p ? text.data() : nullptr;
    *n = p;
    return S_OK;
  }
  DWRITE_READING_DIRECTION STDMETHODCALLTYPE
  GetParagraphReadingDirection() override {
    return DWRITE_READING_DIRECTION_LEFT_TO_RIGHT;
  }
  HRESULT STDMETHODCALLTYPE GetLocaleName(UINT32 p, UINT32 *n,
                                          const WCHAR **locale) override {
    *n = UINT32(text.size() - p);
    *locale = L"ko-KR";
    return S_OK;
  }
  HRESULT STDMETHODCALLTYPE GetNumberSubstitution(
      UINT32 p, UINT32 *n, IDWriteNumberSubstitution **out) override {
    *n = UINT32(text.size() - p);
    *out = nullptr;
    return S_OK;
  }
  HRESULT STDMETHODCALLTYPE SetScriptAnalysis(
      UINT32 p, UINT32 n, const DWRITE_SCRIPT_ANALYSIS *s) override {
    runs.push_back({p, n, *s});
    return S_OK;
  }
  HRESULT STDMETHODCALLTYPE
  SetLineBreakpoints(UINT32, UINT32, const DWRITE_LINE_BREAKPOINT *) override {
    return S_OK;
  }
  HRESULT STDMETHODCALLTYPE SetBidiLevel(UINT32, UINT32, UINT8,
                                         UINT8) override {
    return S_OK;
  }
  HRESULT STDMETHODCALLTYPE
  SetNumberSubstitution(UINT32, UINT32, IDWriteNumberSubstitution *) override {
    return S_OK;
  }
};
// DirectWrite가 제공한 동일 배치의 cubic 경로를 독립 double 값으로 복사한다.
struct Sink : IDWriteGeometrySink {
  std::vector<double> commands;
  double base = 0;
  D2D1_FILL_MODE fill = D2D1_FILL_MODE_WINDING;
  HRESULT STDMETHODCALLTYPE QueryInterface(REFIID id, void **p) override {
    if (id == __uuidof(IUnknown) || id == __uuidof(IDWriteGeometrySink)) {
      *p = this;
      AddRef();
      return S_OK;
    }
    *p = nullptr;
    return E_NOINTERFACE;
  }
  ULONG STDMETHODCALLTYPE AddRef() override { return 1; }
  ULONG STDMETHODCALLTYPE Release() override { return 1; }
  void STDMETHODCALLTYPE SetFillMode(D2D1_FILL_MODE m) override { fill = m; }
  void STDMETHODCALLTYPE SetSegmentFlags(D2D1_PATH_SEGMENT) override {}
  void point(double op, D2D1_POINT_2F p) {
    commands.insert(commands.end(), {op, p.x + base, -double(p.y)});
  }
  void STDMETHODCALLTYPE BeginFigure(D2D1_POINT_2F p,
                                     D2D1_FIGURE_BEGIN) override {
    point(0, p);
  }
  void STDMETHODCALLTYPE AddLines(const D2D1_POINT_2F *p, UINT32 n) override {
    for (UINT32 i = 0; i < n; i++)
      point(1, p[i]);
  }
  void STDMETHODCALLTYPE AddBeziers(const D2D1_BEZIER_SEGMENT *p,
                                    UINT32 n) override {
    for (UINT32 i = 0; i < n; i++) {
      commands.insert(commands.end(),
                      {2, p[i].point1.x + base, -double(p[i].point1.y),
                       p[i].point2.x + base, -double(p[i].point2.y),
                       p[i].point3.x + base, -double(p[i].point3.y)});
    }
  }
  void STDMETHODCALLTYPE EndFigure(D2D1_FIGURE_END f) override {
    if (f == D2D1_FIGURE_END_CLOSED)
      commands.push_back(3);
  }
  HRESULT STDMETHODCALLTYPE Close() override { return S_OK; }
};
struct Context {
  ComPtr<IDWriteFactory> factory;
  ComPtr<IDWriteFontFile> file;
  ComPtr<IDWriteFontFace> face;
  ComPtr<IDWriteTextAnalyzer> analyzer;
  DWRITE_FONT_METRICS metrics{};
  std::mutex mutex;
  explicit Context(const wchar_t *path) {
    check(DWriteCreateFactory(
              DWRITE_FACTORY_TYPE_ISOLATED, __uuidof(IDWriteFactory),
              reinterpret_cast<IUnknown **>(factory.GetAddressOf())),
          "createFactory");
    check(factory->CreateFontFileReference(path, nullptr, &file),
          "openFontFile");
    BOOL supported;
    DWRITE_FONT_FILE_TYPE ft;
    DWRITE_FONT_FACE_TYPE type;
    UINT32 count;
    check(file->Analyze(&supported, &ft, &type, &count), "analyzeFont");
    if (!supported || count != 1 || type != DWRITE_FONT_FACE_TYPE_TRUETYPE)
      throw Failure("unsupportedFontFace", E_NOTIMPL);
    IDWriteFontFile *files[] = {file.Get()};
    check(factory->CreateFontFace(type, 1, files, 0,
                                  DWRITE_FONT_SIMULATIONS_NONE, &face),
          "createFace0");
    face->GetMetrics(&metrics);
    check(factory->CreateTextAnalyzer(&analyzer), "createAnalyzer");
  }
};
static thread_local std::string lastError;
static char *copyError() {
  auto p = new char[lastError.size() + 1];
  memcpy(p, lastError.c_str(), lastError.size() + 1);
  return p;
}
static void error(const Failure &e) {
  std::ostringstream s;
  s << "{\"stage\":\"" << e.what()
    << "\",\"hresult\":" << static_cast<long>(e.hr) << "}";
  lastError = s.str();
}
template <class T>
static void array(std::ostringstream &s, const std::vector<T> &v) {
  s << '[';
  for (size_t i = 0; i < v.size(); i++) {
    if (i)
      s << ',';
    s << +v[i];
  }
  s << ']';
}
extern "C" __declspec(dllexport) void *probe_open(const wchar_t *path,
                                                  char **failure) {
  *failure = nullptr;
  try {
    return new Context(path);
  } catch (const Failure &e) {
    error(e);
    *failure = copyError();
    return nullptr;
  } catch (...) {
    lastError = "{\"stage\":\"nativeInternalFailure\",\"hresult\":-1}";
    *failure = copyError();
    return nullptr;
  }
}
extern "C" __declspec(dllexport) void probe_close(void *p) {
  delete static_cast<Context *>(p);
}
extern "C" __declspec(dllexport) void probe_free(char *p) { delete[] p; }
// 단일 FFI 호출로 여러 문자열을 처리한다. context는 worker 안에서만 사용하며
// 동시 접근도 mutex로 차단한다.
extern "C" __declspec(dllexport) char *
probe_batch(void *ptr, const wchar_t **strings, int count, char **failure) {
  *failure = nullptr;
  try {
    if (!ptr || count < 1 || count > 32)
      throw Failure("invalidBatch", E_INVALIDARG);
    auto &c = *static_cast<Context *>(ptr);
    std::lock_guard<std::mutex> lock(c.mutex);
    std::ostringstream out;
    out << std::setprecision(17) << "{\"upem\":" << c.metrics.designUnitsPerEm
        << ",\"faceIndex\":0,\"runs\":[";
    for (int item = 0; item < count; item++) {
      if (item)
        out << ',';
      Analysis a(strings[item]);
      if (a.text.empty() || a.text.size() > 128)
        throw Failure("unsupportedTextLength", E_INVALIDARG);
      for (auto ch : a.text)
        if (!(ch >= 32 && ch <= 126 || ch >= 0xac00 && ch <= 0xd7a3))
          throw Failure("unsupportedCharacter", E_NOTIMPL);
      auto start = Clock::now();
      check(c.analyzer->AnalyzeScript(&a, 0, UINT32(a.text.size()), &a),
            "analyzeScript");
      std::vector<UINT16> ids, clusters(a.text.size());
      std::vector<float> advances, offsetX, offsetY;
      Sink sink;
      double outlineMs = 0;
      for (const auto &run : a.runs) {
        UINT32 max = run.len * 3 + 32, actual = 0;
        std::vector<UINT16> glyphs(max), cluster(run.len);
        std::vector<DWRITE_SHAPING_TEXT_PROPERTIES> tp(run.len);
        std::vector<DWRITE_SHAPING_GLYPH_PROPERTIES> gp(max);
        check(c.analyzer->GetGlyphs(a.text.data() + run.start, run.len,
                                    c.face.Get(), FALSE, FALSE, &run.script,
                                    L"ko-KR", nullptr, nullptr, nullptr, 0, max,
                                    cluster.data(), tp.data(), glyphs.data(),
                                    gp.data(), &actual),
              "getGlyphs");
        glyphs.resize(actual);
        for (auto id : glyphs)
          if (!id)
            throw Failure("missingGlyph", E_FAIL);
        std::vector<FLOAT> av(actual);
        std::vector<DWRITE_GLYPH_OFFSET> offsets(actual);
        check(c.analyzer->GetGlyphPlacements(
                  a.text.data() + run.start, cluster.data(), tp.data(), run.len,
                  glyphs.data(), gp.data(), actual, c.face.Get(),
                  FLOAT(c.metrics.designUnitsPerEm), FALSE, FALSE, &run.script,
                  L"ko-KR", nullptr, nullptr, 0, av.data(), offsets.data()),
              "placeGlyphs");
        for (UINT32 j = 0; j < run.len; j++)
          clusters[run.start + j] = UINT16(ids.size() + cluster[j]);
        ids.insert(ids.end(), glyphs.begin(), glyphs.end());
        advances.insert(advances.end(), av.begin(), av.end());
        for (auto offset : offsets) {
          offsetX.push_back(offset.advanceOffset);
          offsetY.push_back(offset.ascenderOffset);
        }
        auto ot = Clock::now();
        check(c.face->GetGlyphRunOutline(
                  FLOAT(c.metrics.designUnitsPerEm), glyphs.data(), av.data(),
                  offsets.data(), actual, FALSE, FALSE, &sink),
              "glyphRunOutline");
        outlineMs += ms(ot);
        for (auto advance : av)
          sink.base += advance;
      }
      double total = ms(start);
      out << "{\"glyphs\":";
      array(out, ids);
      out << ",\"clusters\":";
      array(out, clusters);
      out << ",\"advances\":";
      array(out, advances);
      out << ",\"offsetX\":";
      array(out, offsetX);
      out << ",\"offsetY\":";
      array(out, offsetY);
      out << ",\"commands\":";
      array(out, sink.commands);
      out << ",\"fill\":" << int(sink.fill)
          << ",\"shapeMs\":" << total - outlineMs
          << ",\"outlineMs\":" << outlineMs << '}';
    }
    out << "]}";
    auto value = out.str();
    auto result = new char[value.size() + 1];
    memcpy(result, value.c_str(), value.size() + 1);
    return result;
  } catch (const Failure &e) {
    error(e);
    *failure = copyError();
    return nullptr;
  } catch (...) {
    lastError = "{\"stage\":\"nativeInternalFailure\",\"hresult\":-1}";
    *failure = copyError();
    return nullptr;
  }
}