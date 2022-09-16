
include("./ppc.jl")

using BenchmarkTools
using Statistics

n = 1000
r = zeros(Float32, n, n)
r_tmp = zeros(Float32, n, n)
d = rand(Float32, n, n)

time_julia = (mean = [], std = [])
time_gcc = (mean = [], std = [])
time_clang = (mean = [], std = [])

function add_timing!(time, bm)
  push!(time.mean, mean(bm.times))
  push!(time.std, std(bm.times))
end

function reset!(r, r_tmp)
  r_tmp .= r
  fill!(r, 0f0)
end

# get a correct initialization of r_tmp
v0_julia(r_tmp, d)

println("ppc benchmark started (n = $n)")

# iterate through versions and compilers
for version in 0:4
  for compiler in [:julia, :gcc, :clang]
    fname = Symbol("v$(version)_$(compiler)")
    tname = Symbol("time_$(compiler)")
    println("\n$(fname):")
    quote
      bm = @benchmark $fname(r, d)
      display(bm)
      add_timing!($tname, bm)
      m = maximum(abs, r - r_tmp)
      println(" Max. deviation to prev. result: $m")
      reset!(r, r_tmp)
    end |> eval
  end
end

using DelimitedFiles

open("./times.dat", "w") do file
  versions = ["v$i" for i in 0:4]
  println(file, "# julia")
  writedlm(file, [versions [time_julia.mean time_julia.std] ./ 1e9])
  println(file, "\n\n# gcc")
  writedlm(file, [versions [time_gcc.mean time_gcc.std] ./ 1e9])
  println(file, "\n\n# clang")
  writedlm(file, [versions [time_clang.mean time_clang.std] ./ 1e9])
end
