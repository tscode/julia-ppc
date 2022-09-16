
function v0_julia(r :: Matrix{Float32}, d :: Matrix{Float32})

  # sanity checks
  @assert size(r) == size(d)
  @assert size(r, 1) == size(r, 2)

  # dimensions
  n = size(r, 1)

  # solving the shortcut problem
  for i in 1:n, j in 1:n
    v = Inf32
    @inbounds for k in 1:n
      z = d[k, i] + d[j, k]
      v = min(v, z)
    end
    r[j, i] = v
  end

end

function v1_julia(r :: Matrix{Float32}, d :: Matrix{Float32})

  # sanity checks
  @assert size(r) == size(d)
  @assert size(r, 1) == size(r, 2)

  # dimensions and transposed copy
  n = size(r, 1)
  t = collect(d')

  # solving the shortcut problem
  for i in 1:n, j in 1:n
    v = Inf32
    @inbounds for k in 1:n
      z = d[k, i] + t[k, j]
      v = min(v, z)
    end
    r[j, i] = v
  end

end


function v2_julia(r :: Matrix{Float32}, d_ :: Matrix{Float32})

  # sanity checks
  @assert size(r) == size(d_)
  @assert size(r, 1) == size(r, 2)

  # dimensions
  n = size(r, 1)
  nb = 2
  na = div((n + nb - 1), nb)  # smallest multiple of 4 >= n

  # padded / transposed copies
  d = fill(Inf32, (na * nb, n))
  t = fill(Inf32, (na * nb, n))

  d[1:n, 1:n] .= d_
  t[1:n, 1:n] .= d_'

  # make indexing more straightforward
  d = reshape(d, nb, na, :)
  t = reshape(t, nb, na, :)

  # solving the shortcut problem
  vv = fill(Inf32, nb)
  for i in 1:n, j in 1:n
    fill!(vv, Inf32)
    for ka in 1:na
      @inbounds for kb in 1:nb
        z = d[kb, ka, i] + t[kb, ka, j]
        vv[kb] = min(vv[kb], z)
      end
    end
    r[j, i] = minimum(vv)
  end
end


using StaticArrays

# exploit SIMD for static vectors of suitable length
function v3_julia(r :: Matrix{Float32}, d_ :: Matrix{Float32})

  # sanity checks
  @assert size(r) == size(d_)
  @assert size(r, 1) == size(r, 2)

  # dimensions
  n = size(r, 1)
  nb = 8
  na = div((n + nb - 1), nb)

  # padded / transposed copies
  d = fill(Inf32, (na * nb, n))
  t = fill(Inf32, (na * nb, n))

  d[1:n,1:n] .= d_
  t[1:n,1:n] .= d_'

  # use static vectors to enable SIMD
  dr = reinterpret(SVector{nb, Float32}, d) |> collect
  tr = reinterpret(SVector{nb, Float32}, t) |> collect

  # solving the shortcut problem
  vv0 = @SVector fill(Inf32, nb)
  for i in 1:n, j in 1:n
    vv = vv0
    @inbounds for ka in 1:na
      z = dr[ka, i] .+ tr[ka, j]
      vv = min.(vv, z)
    end
    r[j, i] = minimum(vv)
  end

end


# SIMD + better reusage of register data
function v4_julia(r :: Matrix{Float32}, d_ :: Matrix{Float32})

  # sanity checks
  @assert size(r) == size(d_)
  @assert size(r, 1) == size(r, 2)

  # dimensions
  n = size(r, 1)
  nb = 8
  na = div((n + nb - 1), nb)
  nd = 3
  nc = div((n + nd - 1), nd)

  # padded / transposed copies
  d = fill(Inf32, (na * nb, nc * nd))
  t = fill(Inf32, (na * nb, nc * nd))

  d[1:n,1:n] .= d_
  t[1:n,1:n] .= d_'

  # using static vectors to enable SIMD
  dr = reinterpret(SVector{nb, Float32}, d) |> collect
  tr = reinterpret(SVector{nb, Float32}, t) |> collect
  dr = reshape(dr, na, nd, nc)
  tr = reshape(tr, na, nd, nc)

  # solving the shortcut problem
  v0 = @SArray fill(Inf32, nb)
  vv = fill(v0, nd, nd)

  for ic in 1:nc, jc in 1:nc
    fill!(vv, v0)
    @inbounds for ka in 1:na
      y1 = tr[ka, 1, jc]
      y2 = tr[ka, 2, jc]
      y3 = tr[ka, 3, jc]
      x1 = dr[ka, 1, ic]
      x2 = dr[ka, 2, ic]
      x3 = dr[ka, 3, ic]
      vv[1, 1] = min.(vv[1, 1], x1 + y1)
      vv[1, 2] = min.(vv[1, 2], x1 + y2)
      vv[1, 3] = min.(vv[1, 3], x1 + y3)
      vv[2, 1] = min.(vv[2, 1], x2 + y1)
      vv[2, 2] = min.(vv[2, 2], x2 + y2)
      vv[2, 3] = min.(vv[2, 3], x2 + y3)
      vv[3, 1] = min.(vv[3, 1], x3 + y1)
      vv[3, 2] = min.(vv[3, 2], x3 + y2)
      vv[3, 3] = min.(vv[3, 3], x3 + y3)
    end
    @inbounds for id in 1:nd, jd in 1:nd
      i = nd * (ic-1) + id
      j = nd * (jc-1) + jd
      if i <= n && j <= n
        r[j, i] = minimum(vv[id, jd])
      end
    end
  end
end

# wrapped c++ versions

function gen_cpp_wrapper(cc :: Symbol, version :: Int)
  fname = Symbol("v$(version)_$cc")
  cfname = "v$version"
  lib = "./ppc-$cc.so"
  quote
    function $fname(r :: Matrix{Float32}, d :: Matrix{Float32})
      @assert size(r) == size(d)
      @assert size(r, 1) == size(r, 2)
      n = size(r, 1)
      ccall(($cfname, $lib), Nothing, (Ptr{Float32}, Ptr{Float32}, Int), r, d, n)
    end
  end
end

for cc in [:gcc, :clang], version in 0:4
  eval(gen_cpp_wrapper(cc, version))
end



