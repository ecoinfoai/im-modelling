using ImModelling
using Test
using Statistics
using CairoMakie

@testset "ImModelling" begin

    @testset "vibrio_year_counts" begin
        d = vibrio_year_counts()
        @test length(d.year) == length(d.count)      # 짝이 맞아야 한다
        @test d.year[1] == 2001 && d.year[end] == 2025
        @test all(>(0), d.count)                      # 신고 건수는 양수
        @test 40 < mean(d.count) < 70                 # 평균은 상식 범위(≈56)
        @test minimum(d.count) == 24                  # 알려진 최솟값(2009)
        @test maximum(d.count) == 88                  # 알려진 최댓값(2006)
    end

    @testset "vibrio_year_histogram" begin
        fig = vibrio_year_histogram()
        @test fig isa Figure                          # 그림을 반환한다
    end

    @testset "seoul_daily_temperature" begin
        t = seoul_daily_temperature()
        @test length(t) == 365                        # 하루도 빠짐없이
        @test 8 < mean(t) < 18                         # 연평균이 상식 범위
        @test maximum(t) > 25 && minimum(t) < 0        # 여름 더위와 겨울 추위 양쪽
        # 재현성: 같은 seed면 같은 결과
        @test seoul_daily_temperature(seed = 1) == seoul_daily_temperature(seed = 1)
        @test seoul_daily_temperature(seed = 1) != seoul_daily_temperature(seed = 2)
    end

    @testset "seoul_temp_bimodal" begin
        fig = seoul_temp_bimodal()
        @test fig isa Figure
    end

    # ── Ch.3 교수 데모 5종 ─────────────────────────────────────────────────

    @testset "summer_100runs" begin
        d = summer_100runs_counts()
        @test length(d.counts) == d.nruns == 100
        @test all(>=(0), d.counts)                    # 건수는 음수가 될 수 없다
        @test 1.3 < d.mean < 2.7                      # 평균 2 근처
        @test d.nzero > 0                             # 0명인 해 존재(Poisson2: ≈13.5%)
        # 재현성
        @test summer_100runs_counts(seed = 1).counts == summer_100runs_counts(seed = 1).counts
        @test summer_100runs_counts(seed = 1).counts != summer_100runs_counts(seed = 2).counts
        @test demo_summer_100runs() isa Figure
    end

    @testset "distribution_gallery" begin
        s = distribution_gallery_specs()
        @test length(propertynames(s)) == 4           # 네 분포
        @test demo_distribution_gallery() isa Figure
    end

    @testset "vibrio_forecast" begin
        cv = vibrio_forecast_curve()
        @test issorted(cv.risk)                       # 수온↑ → 위험↑ (단조증가)
        @test cv.risk[1] < 0.2 && cv.risk[end] > 0.9  # 저수온 저위험, 고수온 고위험
        fan = vibrio_forecast_fan()
        w = fan.sst_hi .- fan.sst_lo
        @test issorted(w) && w[end] > w[1]            # 예보 멀수록 불확실성 띠 확대
        @test demo_vibrio_forecast() isa Figure
    end

    @testset "distribution_shift" begin
        d = distribution_shift_data()
        @test d.tail_present > d.tail_past            # 오른쪽 이동 → 고위험 꼬리 커짐
        @test 4.0 < d.ratio < 6.0                     # 약 5배(기본 파라미터)
        @test demo_distribution_shift() isa Figure
    end

    @testset "intervention_effect" begin
        d = intervention_effect_data()
        mb = mean(d.baseline)
        @test mean(d.edu) < mb - 0.5                                   # ① 노출↓ → 봉우리(중심) 왼쪽
        @test quantile(d.treat, 0.99) < quantile(d.baseline, 0.99)     # ② 발생은 그대로, 최악의 꼬리를 자름
        @test isapprox(mean(d.monitor), mb; atol = 0.6)               # ③ 중심(발생 평균)은 유지
        @test quantile(d.monitor, 0.95) < quantile(d.baseline, 0.95)  #    하되 큰 해(꼬리)는 누른다
        @test intervention_effect_data(seed = 1).baseline == intervention_effect_data(seed = 1).baseline
        @test demo_intervention_effect() isa Figure
    end

end
