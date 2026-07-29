"""
    ImModelling

감염미생물학 12–14주차 교안의 시뮬레이션·그림 생성 코드.

설계 원칙
- 모든 계산·작도 로직은 이 패키지(`src/`)에 둔다. 문서(`docs/`)의 `{julia}` 블록은
  이 함수들을 **호출만** 한다. 그래야 `test/`에서 Test.jl 로 단위 검증이 가능하다.
- 각 함수는 데이터(`NamedTuple`/배열)와 그림(`Figure`)을 분리해 반환하거나, 그림을
  반환하되 내부 수치를 함수 인자로 노출한다. 검증은 수치를, 문서는 그림을 쓴다.

현재 구현 상태
- `vibrio_year_counts`, `vibrio_year_histogram`  … ch3_fig2 대체 (구현 완료)
- `seoul_daily_temperature`, `seoul_temp_bimodal`  … ch3_fig4 대체 (구현 완료)
- Ch.3 교수 데모 5종 (구현 완료):
    `demo_summer_100runs`       … §3 같은 여름 100번 재생(몬테카를로)
    `demo_distribution_gallery` … §2 정규·이항·푸아송·로그노멀 모양 갤러리
    `demo_vibrio_forecast`      … §4 해수온→위험 예보 + 불확실성 부챗살
    `demo_distribution_shift`   … §5 두 시대 분포 이동 → 꼬리 면적 급증
    `demo_intervention_effect`  … §6 개입 3종이 사망자 분포를 바꾸는 방식
- Ch.1·Ch.2 교수 데모는 아래 "교수 데모(미구현)" 섹션에 시그니처만 두었다.
"""
module ImModelling

using CairoMakie
using Distributions
using Random
using Statistics
using Printf

export vibrio_year_counts, vibrio_year_histogram
export seoul_daily_temperature, seoul_temp_bimodal
# Ch.3 교수 데모 (데이터 함수 + 그림 함수)
export summer_100runs_counts, demo_summer_100runs
export distribution_gallery_specs, demo_distribution_gallery
export vibrio_forecast_curve, vibrio_forecast_fan, demo_vibrio_forecast
export distribution_shift_data, demo_distribution_shift
export intervention_effect_data, demo_intervention_effect

# 헤드리스(서버·CI) 환경에서 안전하게 PNG를 굽는 백엔드
function __init__()
    CairoMakie.activate!(type = "png", px_per_unit = 2)
    return nothing
end

# ─────────────────────────────────────────────────────────────────────────────
# ch3_fig2 대체 — 국내 비브리오패혈증 연도별 신고 건수의 분포
# ─────────────────────────────────────────────────────────────────────────────

"""
    vibrio_year_counts() -> NamedTuple{(:year, :count)}

국내 비브리오패혈증 연간 신고 건수(2001–2025). 값은 질병관리청 감염병포털 신고 자료를
바탕으로 한 잠정치이며, 최종 게시 전 원자료로 확정할 것.
"""
function vibrio_year_counts()
    year = collect(2001:2025)
    count = [41, 58, 80, 58, 57, 88, 58, 58, 24, 49,
             73, 51, 64, 56, 61, 37, 56, 46, 47, 42,
             70, 52, 46, 69, 49]
    @assert length(year) == length(count)
    return (year = year, count = count)
end

"""
    vibrio_year_histogram(; data = vibrio_year_counts()) -> Figure

연간 신고 건수의 분포(히스토그램)와 평균선을 그린다. "평균은 하나지만 해마다 폭넓게
흩어진다"를 보여 주는 그림 — Ch.3 2절 `ch3_fig2` 를 대체한다.
"""
function vibrio_year_histogram(; data = vibrio_year_counts(), font = "Noto Sans KR")
    c = data.count
    fig = Figure(size = (900, 420); fonts = (; regular = font, bold = font))
    ax = Axis(fig[1, 1],
        xlabel = "Annual reported cases", ylabel = "Number of years",
        title = "Annual V. vulnificus sepsis cases in Korea (2001–2025, n = $(length(c)))",
        xgridvisible = false)
    hist!(ax, c, bins = 20:10:90, color = (:steelblue, 0.85),
          strokewidth = 0.5, strokecolor = :white)
    vlines!(ax, [mean(c)], color = :orangered, linestyle = :dash, linewidth = 2.5)
    text!(ax, mean(c) + 1.5, 6.3;
          text = @sprintf("Mean %.0f", mean(c)), color = :orangered, fontsize = 15)
    return fig
end

# ─────────────────────────────────────────────────────────────────────────────
# ch3_fig4 대체 — 어느 지역 일 년치 일 기온의 이봉(bimodal) 분포
# ─────────────────────────────────────────────────────────────────────────────

"""
    seoul_daily_temperature(; seed = 20260728) -> Vector{Float64}

한 해 365일의 일평균 기온을 이상화된 계절 주기(연평균 약 12.8 ℃) + 일 변동으로 생성한다.
봄·가을에 몰리고 한여름·한겨울 양쪽에 봉우리가 생겨 '연평균인 날은 오히려 드문' 이봉 구조.
"""
function seoul_daily_temperature(; seed::Integer = 20260728, annual_mean = 12.8, amplitude = 12.0)
    rng = MersenneTwister(seed)
    days = 1:365
    # 최저(1월)–최고(7월 말) 계절 주기
    seasonal = annual_mean .- amplitude .* cos.(2π .* (days .- 15) ./ 365)
    noise = rand(rng, Normal(0, 2.5), length(days))
    return seasonal .+ noise
end

"""
    seoul_temp_bimodal(; temps = seoul_daily_temperature()) -> Figure

일 기온 히스토그램에 연평균선을 얹어, 평균값이 정작 골짜기(드문 값)에 떨어지는 것을
보여 준다 — Ch.3 2절 `ch3_fig4` 를 대체한다.
"""
function seoul_temp_bimodal(; temps = seoul_daily_temperature(), font = "Noto Sans KR")
    m = mean(temps)
    fig = Figure(size = (900, 440); fonts = (; regular = font, bold = font))
    ax = Axis(fig[1, 1],
        xlabel = "Daily mean temperature (°C)", ylabel = "Days per year",
        title = "One year of daily temperatures — two peaks",
        xgridvisible = false)
    hist!(ax, temps, bins = 24, color = (:teal, 0.75),
          strokewidth = 0.5, strokecolor = :white)
    vlines!(ax, [m], color = :orangered, linestyle = :dash, linewidth = 2.5)
    text!(ax, m + 0.5, 3.0;
          text = @sprintf("Annual mean %.1f°C\n(falls in the valley)", m),
          color = :orangered, fontsize = 14, align = (:left, :bottom))
    return fig
end

# ─────────────────────────────────────────────────────────────────────────────
# 교수 데모 (미구현) — 시그니처만. 구현되면 위 두 함수처럼 Figure 를 반환하도록 채운다.
#   문서에서 호출하기 전까지는 렌더 시 실행되지 않으므로 error 로 막아 둔다.
# ─────────────────────────────────────────────────────────────────────────────

# Ch.1
"부산 여름철 폭염일수·장마 추세 — 변덕(날씨) vs 추세(기후)"
demo_busan_climate_trend(args...; kw...) = error("미구현: demo_busan_climate_trend")
"지구 평균기온·해빙, 산불–한파, IOD–장마–남조류 연쇄 시각화"
demo_teleconnection_chain(args...; kw...) = error("미구현: demo_teleconnection_chain")

# Ch.2
"방어막 0→3겹, 남은 위험이 1/10씩 줄어드는 곱셈 데모"
demo_barrier_multiplication(args...; kw...) = error("미구현: demo_barrier_multiplication")
"몬테카를로 동전 던지기 — 큰수의 법칙(0.5 수렴)"
demo_lln_coin(args...; kw...) = error("미구현: demo_lln_coin")
"위험군 비율 슬라이더 → 1,000명 중 예상 사망자 격자"
demo_risk_group_grid(args...; kw...) = error("미구현: demo_risk_group_grid")
"인원×확률 기댓값 계산기 + 100회 재생 히스토그램"
demo_expected_value(args...; kw...) = error("미구현: demo_expected_value")

# Ch.3 교수 데모는 아래 별도 섹션에서 구현했다(파일 하단).

# ═════════════════════════════════════════════════════════════════════════════
#  Ch.3 §3 — demo_summer_100runs
#  "같은 여름 100번 재생" — 하나의 평균 뒤에 숨은 분포
#  본문 근거: "모의 실험에서 '평균 2명인 여름'을 100번 돌려 보면, 0명인 해가 대략
#  열서너 번은 나온다"(Poisson(2)의 P(0)=e^{-2}≈0.135). 챕터 2 동전 데모의 병(病) 버전.
# ═════════════════════════════════════════════════════════════════════════════

"""
    summer_100runs_counts(; seed = 20260729, λ = 2.0, nruns = 100) -> NamedTuple

같은 조건('평균 λ명인 여름')을 `nruns`번 재생한 몬테카를로 결과. 각 해의 신고 건수는
`Poisson(λ)`에서 뽑는다. 반환: `(counts, λ, nruns, nzero, mean)`.
"""
function summer_100runs_counts(; seed::Integer = 20260729, λ::Real = 2.0, nruns::Integer = 100)
    rng = MersenneTwister(seed)
    counts = rand(rng, Poisson(λ), nruns)
    return (counts = counts, λ = float(λ), nruns = nruns,
            nzero = count(==(0), counts), mean = mean(counts))
end

"""
    demo_summer_100runs(; data = summer_100runs_counts(), font = "Noto Sans KR") -> Figure

100번 재생한 여름의 신고 건수 분포(막대) + 평균선. "평균은 하나지만 현실은 매번 다르다".
"""
function demo_summer_100runs(; data = summer_100runs_counts(), font = "Noto Sans KR")
    c = data.counts
    ks = 0:maximum(c)
    freq = [count(==(k), c) for k in ks]
    fig = Figure(size = (900, 460); fonts = (; regular = font, bold = font))
    ax = Axis(fig[1, 1],
        xlabel = "Reported cases in one summer", ylabel = "Number of such years (/ $(data.nruns) runs)",
        title = "Replaying a 'mean-$(round(Int, data.λ))-cases summer' $(data.nruns) times",
        xticks = collect(ks), xgridvisible = false)
    barplot!(ax, collect(ks), freq; color = (:steelblue, 0.85),
             strokewidth = 0.5, strokecolor = :white)
    vlines!(ax, [data.λ], color = :orangered, linestyle = :dash, linewidth = 2.5)
    text!(ax, data.λ + 0.15, maximum(freq) * 0.92;
          text = @sprintf("Mean %.1f", data.λ), color = :orangered,
          fontsize = 15, align = (:left, :center))
    text!(ax, 0, freq[1];
          text = "0-case years\n$(data.nzero) times", color = :gray25, fontsize = 12,
          align = (:center, :bottom), offset = (0, 4))
    return fig
end

# ═════════════════════════════════════════════════════════════════════════════
#  Ch.3 §2 — demo_distribution_gallery
#  정규·이항·푸아송·로그노멀 '모양 갤러리'. 정적 삽화 ch3_fig3 을 코드 그림으로 대체.
#  라벨은 모두 본문의 감염 예시에서 가져온다.
# ═════════════════════════════════════════════════════════════════════════════

"""
    distribution_gallery_specs() -> NamedTuple

갤러리에 실을 네 분포와 감염 예시 라벨. 각 항목은 `(dist, kind, name, ex)`.
- 정규   : 체온·혈압·키처럼 여러 요인이 더해진 연속값
- 이항   : 백신 20명 중 항체 형성 수(n=20, p=0.9)
- 푸아송 : 한 여름 비브리오 신고 건수(평균 2 = 챕터 2 기댓값)
- 로그노멀: 잠복기 — 대부분 짧고 드물게 긺(Sartwell, 1950)
"""
function distribution_gallery_specs()
    return (
        normal    = (dist = Normal(36.5, 0.4),      kind = :continuous,
                     name = "Normal",      ex = "e.g., body temp · BP · height"),
        binomial  = (dist = Binomial(20, 0.9),      kind = :discrete,
                     name = "Binomial",    ex = "e.g., antibody responders in 20 vaccinated"),
        poisson   = (dist = Poisson(2.0),           kind = :discrete,
                     name = "Poisson",     ex = "e.g., summer Vibrio cases (mean 2)"),
        lognormal = (dist = LogNormal(log(5), 0.5), kind = :continuous,
                     name = "Log-normal",  ex = "e.g., incubation period (mostly short, rarely long)"),
    )
end

"""
    demo_distribution_gallery(; specs = distribution_gallery_specs(), font = "Noto Sans KR") -> Figure

네 분포를 2×2로 나란히. 연속형은 밀도 곡선, 이산형은 확률막대. 값이 아니라 '모양'을 본다.
"""
function demo_distribution_gallery(; specs = distribution_gallery_specs(), font = "Noto Sans KR")
    fig = Figure(size = (960, 720); fonts = (; regular = font, bold = font))
    order = (:normal, :binomial, :poisson, :lognormal)
    pos = ((1, 1), (1, 2), (2, 1), (2, 2))
    cols = (:steelblue, :seagreen, :orange, :purple)
    for (i, key) in enumerate(order)
        s = getproperty(specs, key)
        r, c = pos[i]
        ax = Axis(fig[r, c], title = "$(s.name)\n$(s.ex)",
                  ylabel = "Probability (density)", xgridvisible = false)
        col = cols[i]
        if s.kind == :discrete
            klo = max(0, floor(Int, quantile(s.dist, 0.001)))
            khi = ceil(Int, quantile(s.dist, 0.999))
            ks = klo:khi
            barplot!(ax, collect(ks), pdf.(s.dist, ks); color = (col, 0.85),
                     strokewidth = 0.4, strokecolor = :white)
            ax.xlabel = "Count"
        else
            lo = quantile(s.dist, 0.001); hi = quantile(s.dist, 0.999)
            xs = range(lo, hi; length = 300)
            ys = pdf.(s.dist, xs)
            band!(ax, xs, zeros(length(xs)), ys; color = (col, 0.20))
            lines!(ax, xs, ys; color = col, linewidth = 2.5)
            ax.xlabel = "Value"
        end
    end
    Label(fig[0, :], "Four faces of distributions — recognized by infection examples";
          fontsize = 19, font = font, padding = (0, 0, 6, 0))
    return fig
end

# ═════════════════════════════════════════════════════════════════════════════
#  Ch.3 §4 — demo_vibrio_forecast
#  해수온 → 비브리오 위험 등급, 그리고 예보 시점이 멀수록 넓어지는 불확실성 부챗살.
#  출처: NOAA NCCOS 체서피크만 Vibrio 예보(수온 ~15℃↑ 활발), ECDC Vibrio Map Viewer
#  (수온 ~18℃↑), Semenza et al.(2017), Kim & Chun(2021, 최고 해수온이 최강 예측 인자).
#  NOAA 한계: '어디에' 나타날지는 예측하나 '얼마나·감수성'은 예측하지 않음.
# ═════════════════════════════════════════════════════════════════════════════

"""
    vibrio_forecast_curve(; sst = 8:0.1:30) -> NamedTuple

해수 표층 수온(℃)에 따른 비브리오 위험(0~1, 상대). 로지스틱으로 15℃ 부근에서 상승을
시작해 22℃ 이상에서 고위험. 반환: `(sst, risk)`.
"""
function vibrio_forecast_curve(; sst = 8:0.1:30)
    s = collect(float.(sst))
    risk = 1 ./ (1 .+ exp.(-(s .- 19) ./ 2.2))
    return (sst = s, risk = risk)
end

"""
    vibrio_forecast_fan(; sst0 = 21.0, drift = 0.15, σ0 = 0.3, growth = 0.35, days = 0:7) -> NamedTuple

예보 시점(일 후)에 따른 예측 수온과 95% 불확실성 띠. 시점이 멀수록 띠 폭이 넓어진다.
반환: `(day, sst_mean, sst_lo, sst_hi, width)`.
"""
function vibrio_forecast_fan(; sst0 = 21.0, drift = 0.15, σ0 = 0.3, growth = 0.35, days = 0:7)
    d = collect(float.(days))
    m = sst0 .+ drift .* d
    w = σ0 .+ growth .* d
    return (day = d, sst_mean = m, sst_lo = m .- 1.96 .* w, sst_hi = m .+ 1.96 .* w, width = w)
end

"""
    demo_vibrio_forecast(; curve = vibrio_forecast_curve(), fan = vibrio_forecast_fan(),
                           font = "Noto Sans KR") -> Figure

(a) 수온→위험 곡선(등급 배경 + NOAA 15℃·ECDC 18℃ 문턱), (b) 예보 부챗살(멀수록 확대).
"""
function demo_vibrio_forecast(; curve = vibrio_forecast_curve(), fan = vibrio_forecast_fan(),
                                font = "Noto Sans KR")
    fig = Figure(size = (1000, 470); fonts = (; regular = font, bold = font))

    # (a) risk–SST curve
    axa = Axis(fig[1, 1], xlabel = "Sea surface temperature (°C)", ylabel = "Vibrio risk (relative)",
               title = "(a) Temperature sets the risk", xgridvisible = false)
    edges = (8.0, 15.0, 18.0, 22.0, 30.0)
    bandcols = ((:gray, 0.06), (:gold, 0.12), (:orange, 0.14), (:red, 0.14))
    for i in 1:4
        poly!(axa, Point2f[(edges[i], 0), (edges[i+1], 0), (edges[i+1], 1), (edges[i], 1)];
              color = bandcols[i])
    end
    lines!(axa, curve.sst, curve.risk; color = :steelblue, linewidth = 3)
    vlines!(axa, [15.0], color = :seagreen, linestyle = :dash, linewidth = 2)
    vlines!(axa, [18.0], color = :purple, linestyle = :dash, linewidth = 2)
    text!(axa, 15, 1.02; text = "NOAA 15°C", color = :seagreen, fontsize = 11, align = (:center, :bottom))
    text!(axa, 18, 1.10; text = "ECDC 18°C", color = :purple, fontsize = 11, align = (:center, :bottom))
    text!(axa, 26, 0.10; text = "Very high", color = :red, fontsize = 12, align = (:center, :bottom))
    ylims!(axa, 0, 1.18)

    # (b) forecast fan
    axb = Axis(fig[1, 2], xlabel = "Forecast horizon (days ahead)", ylabel = "Predicted SST (°C)",
               title = "(b) Uncertainty widens with horizon", xgridvisible = false)
    band!(axb, fan.day, fan.sst_lo, fan.sst_hi; color = (:steelblue, 0.25))
    lines!(axb, fan.day, fan.sst_mean; color = :steelblue, linewidth = 3)
    scatter!(axb, fan.day, fan.sst_mean; color = :steelblue, markersize = 7)
    hlines!(axb, [22.0], color = (:red, 0.6), linestyle = :dot, linewidth = 1.5)
    text!(axb, 0.1, 22.15; text = "High-risk band (22°C+)", color = :red, fontsize = 11, align = (:left, :bottom))
    return fig
end

# ═════════════════════════════════════════════════════════════════════════════
#  Ch.3 §5 — demo_distribution_shift
#  두 시대의 분포를 겹쳐 하나를 오른쪽으로 밀면, 고위험(꼬리) 면적이 몇 배로 커진다.
#  출처: Hansen et al.(2012, "무거워진 주사위"); 국립수산과학원(2023, 한국 해역 표층수온
#  54년간 약 1.35℃ 상승 = 지구 평균의 약 2.5배); Baker-Austin et al.(2013).
# ═════════════════════════════════════════════════════════════════════════════

"""
    distribution_shift_data(; μ_past = 22.0, σ = 1.6, Δ = 1.35, thr = 25.0) -> NamedTuple

과거/현재 두 정규분포(현재 = 과거를 Δ만큼 오른쪽 이동)와, 문턱 `thr` 초과(고위험) 꼬리
확률. 기본값은 늦여름 표층수온(℃), Δ=1.35℃는 수과원(2023) 값. 반환에 `ratio`(배수) 포함.
"""
function distribution_shift_data(; μ_past = 22.0, σ = 1.6, Δ = 1.35, thr = 25.0)
    past = Normal(μ_past, σ)
    present = Normal(μ_past + Δ, σ)
    tp = ccdf(past, thr)
    tq = ccdf(present, thr)
    return (past = past, present = present, thr = float(thr), Δ = float(Δ),
            tail_past = tp, tail_present = tq, ratio = tq / tp)
end

"""
    demo_distribution_shift(; data = distribution_shift_data(), font = "Noto Sans KR") -> Figure

두 밀도 곡선 + 문턱선 + 꼬리 음영. "평균이 조금 밀렸을 뿐인데 극단은 훨씬 자주".
"""
function demo_distribution_shift(; data = distribution_shift_data(), font = "Noto Sans KR")
    fig = Figure(size = (940, 480); fonts = (; regular = font, bold = font))
    ax = Axis(fig[1, 1], xlabel = "Late-summer SST (°C)", ylabel = "Relative frequency (density)",
        title = @sprintf("A %.2f°C shift multiplies high-risk (>%.0f°C) probability %.1f×",
                         data.Δ, data.thr, data.ratio),
        xgridvisible = false)
    lo = quantile(data.past, 0.0005); hi = quantile(data.present, 0.9995)
    xs = range(lo, hi; length = 400)
    yp = pdf.(data.past, xs); yq = pdf.(data.present, xs)
    lines!(ax, xs, yp; color = (:steelblue, 0.95), linewidth = 2.5, label = "Past (e.g., 1980s)")
    lines!(ax, xs, yq; color = (:orangered, 0.95), linewidth = 2.5, label = "Present (e.g., 2020s)")
    xt = range(data.thr, hi; length = 200)
    band!(ax, xt, zeros(length(xt)), pdf.(data.past, xt);    color = (:steelblue, 0.30))
    band!(ax, xt, zeros(length(xt)), pdf.(data.present, xt); color = (:orangered, 0.30))
    vlines!(ax, [data.thr], color = :black, linestyle = :dash, linewidth = 1.5)
    text!(ax, data.thr + 0.15, maximum(yq) * 0.55;
          text = @sprintf("High-risk tail area\n%.1f%%  →  %.1f%%", 100data.tail_past, 100data.tail_present),
          color = :gray15, fontsize = 13, align = (:left, :center))
    axislegend(ax; position = :lt, framevisible = false)
    return fig
end

# ═════════════════════════════════════════════════════════════════════════════
#  Ch.3 §6 — demo_intervention_effect
#  개입마다 사망자 수 분포를 바꾸는 '방식'이 다르다.
#    ① 위험군 교육·회 자제 → 노출↓ → 봉우리(중심)를 왼쪽으로
#    ② 조기 진단·치료      → 치명률↓ → 사망이라는 최악의 꼬리를 자름
#    ③ 연안 모니터링·경보  → 큰 해(초전파식 과대분산)↓ → 오른쪽 꼬리를 압축
#  발생은 과대분산(초전파, §3)을 반영해 음이항으로, 사망은 이항(치명률)으로 모형화.
# ═════════════════════════════════════════════════════════════════════════════

# 평균 μ, 분산모수 r(작을수록 과대분산 큼)로 음이항을 만든다: mean = μ, var = μ + μ²/r.
_nb_mean_r(μ, r) = NegativeBinomial(r, r / (r + μ))

"""
    intervention_effect_data(; seed = 20260729, nyears = 2000,
                               μ_cases = 10.0, r_disp = 1.5, cfr = 0.40) -> NamedTuple

기준 및 개입 3종에서 '한 해 사망자 수'를 각각 `nyears`번 재생. 발생 건수 ~ 음이항(μ, r),
사망 ~ 이항(발생, cfr). 반환: `(baseline, edu, treat, monitor)` 각 정수 벡터.
"""
function intervention_effect_data(; seed::Integer = 20260729, nyears::Integer = 2000,
                                    μ_cases = 10.0, r_disp = 1.5, cfr = 0.40,
                                    surge = 20, surge_factor = 0.30)
    rng = MersenneTwister(seed)
    deaths_from(cases, f) = Int[rand(rng, Binomial(c, f)) for c in cases]
    # 기준(개입 없음)
    baseline = deaths_from(rand(rng, _nb_mean_r(μ_cases, r_disp), nyears), cfr)
    # ① 노출↓ → 발생 자체가 줄어 봉우리(중심)가 왼쪽으로
    edu = deaths_from(rand(rng, _nb_mean_r(μ_cases * 0.6, r_disp), nyears), cfr)
    # ② 치료 → 발생은 그대로, 큰 발생 해(> surge)의 치명률만 낮춰 '사망 꼬리'를 자름
    ct = rand(rng, _nb_mean_r(μ_cases, r_disp), nyears)
    treat = Int[rand(rng, Binomial(c, c > surge ? cfr * surge_factor : cfr)) for c in ct]
    # ③ 경보 → 큰 발생 해(과대분산)를 줄여 오른쪽 꼬리를 누름(발생 평균은 유지)
    monitor = deaths_from(rand(rng, _nb_mean_r(μ_cases, r_disp * 6), nyears), cfr)
    return (baseline = baseline, edu = edu, treat = treat, monitor = monitor)
end

"""
    demo_intervention_effect(; data = intervention_effect_data(), font = "Noto Sans KR") -> Figure

기준 대비 개입 3종의 사망자 수 분포를 2×2로 비교. 평균선(중심)과 95백분위선(꼬리)을 함께
표시해 "어떤 대책이 봉우리를 낮추고, 어떤 대책이 꼬리를 자르는가"를 눈으로 확인시킨다.
"""
function demo_intervention_effect(; data = intervention_effect_data(), font = "Noto Sans KR")
    scen = ((:baseline, "Baseline (no intervention)", :gray40),
            (:edu,     "(1) Risk-group education / avoid raw seafood\n→ shift the peak left", :seagreen),
            (:treat,   "(2) Early diagnosis & treatment\n→ cut the fatal tail", :steelblue),
            (:monitor, "(3) Coastal monitoring & alerts\n→ suppress bad years (tail)", :orange))
    allv = vcat(data.baseline, data.edu, data.treat, data.monitor)
    xhi = ceil(quantile(allv, 0.999))
    edges = -0.5:1.0:(xhi + 0.5)
    fig = Figure(size = (980, 720); fonts = (; regular = font, bold = font))
    pos = ((1, 1), (1, 2), (2, 1), (2, 2))
    for (i, (key, ttl, col)) in enumerate(scen)
        v = getproperty(data, key)
        r, c = pos[i]
        ax = Axis(fig[r, c], title = ttl, xlabel = "Deaths in one year", ylabel = "Number of years",
                  xgridvisible = false)
        hist!(ax, v; bins = edges, color = (col, 0.8), strokewidth = 0.3, strokecolor = :white)
        m = mean(v); p95 = quantile(v, 0.95)
        vlines!(ax, [m], color = :orangered, linestyle = :dash, linewidth = 2)
        vlines!(ax, [p95], color = :black, linestyle = :dot, linewidth = 1.5)
        xlims!(ax, first(edges), last(edges))
        text!(ax, m, 0; text = @sprintf("Mean %.1f", m), color = :orangered,
              fontsize = 11, align = (:left, :bottom), offset = (3, 3))
        text!(ax, p95, 0; text = @sprintf("95th %.0f", p95), color = :gray15,
              fontsize = 10, align = (:left, :bottom), offset = (3, 18))
    end
    Label(fig[0, :], "Each intervention reshapes the distribution differently — lower the peak vs. cut the tail";
          fontsize = 17, font = font, padding = (0, 0, 6, 0))
    return fig
end

end # module
