using DynamicsMetrics

println("=== Temporal diagnostics ===")

# Two periodic state variables sampled over 32 time steps.
t = collect(0:31)
signal = [
    sin.(2π .* t ./ 8)'
    cos.(2π .* t ./ 8)'
]

acf = evaluate(
    Autocorrelation(
        maxlag=8,
        demean=true,
        normalize=true,
        reduction=:state,
    ),
    signal;
    dt=0.25,
)

psd = evaluate(
    PowerSpectralDensity(
        detrend=:mean,
        one_sided=true,
        reduction=:state,
    ),
    signal;
    dt=0.25,
)

entropy = evaluate(
    SpectralEntropy(
        detrend=:mean,
        reduction=:state,
        normalize=true,
    ),
    signal,
)

println("Autocorrelation lag axis: ", acf.axis)
println("State 1 autocorrelation:  ", vec(acf.values[1, :]))

peak_indices = [argmax(vec(psd.values[state, :])) for state in axes(psd.values, 1)]
peak_frequencies = [psd.axis[index] for index in peak_indices]
println("Dominant frequency by state: ", peak_frequencies)
println("Normalized spectral entropy: ", entropy.values)

println("\nInterpretation: periodic signals concentrate power at a dominant frequency")
println("and therefore have relatively low spectral entropy.")
