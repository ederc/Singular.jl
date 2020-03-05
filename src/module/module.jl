export jet, minimal_generating_set, ModuleClass, rank, smodule, slimgb, eliminate, modulo, lift

###############################################################################
#
#   Basic manipulation
#
###############################################################################

parent(a::smodule{T}) where T <: Nemo.RingElem = ModuleClass{T}(a.base_ring)

base_ring(S::ModuleClass) = S.base_ring

base_ring(I::smodule) = I.base_ring

elem_type(::ModuleClass{T}) where T <: AbstractAlgebra.RingElem = smodule{T}

elem_type(::Type{ModuleClass{T}}) where T <: AbstractAlgebra.RingElem = smodule{T}

parent_type(::Type{smodule{T}}) where T <: AbstractAlgebra.RingElem = ModuleClass{T}


@doc Markdown.doc"""
    ngens(I::smodule)
> Return the number of generators in the current representation of the module (as a list
> of vectors).
"""
ngens(I::smodule) = I.ptr == C_NULL ? 0 : Int(libSingular.ngens(I.ptr))

@doc Markdown.doc"""
    rank(I::smodule)
> Return the rank $n$ of the ambient space $R^n$ of which this module is a submodule.
"""
rank(I::smodule) = Int(libSingular.rank(I.ptr))

function checkbounds(I::smodule, i::Int)
   (i > ngens(I) || i < 1) && throw(BoundsError(I, i))
end

function getindex(I::smodule{T}, i::Int) where T <: AbstractAlgebra.RingElem
   checkbounds(I, i)
   R = base_ring(I)
   p = libSingular.getindex(I.ptr, Cint(i - 1))
   return svector{T}(R, rank(I), libSingular.p_Copy(p, R.ptr))
end

@doc Markdown.doc"""
    iszero(p::smodule)
> Return `true` if this is algebraically the zero module.
"""
iszero(p::smodule) = Bool(libSingular.idIs0(p.ptr))

function deepcopy_internal(I::smodule, dict::IdDict)
   R = base_ring(I)
   ptr = libSingular.id_Copy(I.ptr, R.ptr)
   return Module(R, ptr)
end

function hash(M::smodule, h::UInt)
   v = 0x403fd5a7748e75c9%UInt
   for i in 1:ngens(M)
      v = xor(hash(M[i], h), v)
   end
   return v
end

###############################################################################
#
#   String I/O
#
###############################################################################

function show(io::IO, S::ModuleClass)
   print(io, "Class of Singular Modules over ")
   show(io, base_ring(S))
end

function show(io::IO, I::smodule)
   print(io, "Singular Module over ")
   show(io, base_ring(I))
   println(io,", with Generators:")
   n = ngens(I)
   for i = 1:n
      show(io, I[i])
      if i != n
         println(io, "")
      end
   end
end

###############################################################################
#
#   Groebner basis
#
###############################################################################

@doc Markdown.doc"""
    std(I::smodule; complete_reduction::Bool=false)
> Compute the Groebner basis of the module $I$. If `complete_reduction` is
> set to `true`, the result is unique, up to permutation of the generators
> and multiplication by constants. If not, only the leading terms are unique
> (up to permutation of the generators and multiplication by constants, of
> course). Presently the polynomial ring used must be over a field or over
> the Singular integers.
"""
function std(I::smodule; complete_reduction::Bool=false)
   R = base_ring(I)
   ptr = libSingular.id_Std(I.ptr, R.ptr, complete_reduction)
   libSingular.idSkipZeroes(ptr)
   z = Module(R, ptr)
   z.isGB = true
   return z
end

@doc Markdown.doc"""
   slimgb(I::smodule; complete_reduction::Bool=false)
> Given a module $I$ this function computes a Groebner basis for it.
> Compared to `std`, `slimgb` uses different strategies for choosing
> a reducer.
>
> If the optional parameter `complete_reduction` is set to `true` the
> function computes a reduced Gröbner basis for $I$.
"""
function slimgb(I::smodule; complete_reduction::Bool=false)
   R = base_ring(I)
   ptr = libSingular.id_Slimgb(I.ptr, R.ptr, complete_reduction)
   libSingular.idSkipZeroes(ptr)
   z = Module(R, ptr)
   z.isGB = true
   return z
end

###############################################################################
#
#   Syzygies
#
###############################################################################

@doc Markdown.doc"""
    syz(M::smodule)
> Compute the module of syzygies of the given module. This will be given as
> a set of generators in an ambient space $R^n$, where $n$ is the number of
> generators in $M$.
"""
function syz(M::smodule)
   R = base_ring(M)
   ptr = libSingular.id_Syzygies(M.ptr, R.ptr)
   libSingular.idSkipZeroes(ptr)
   return Module(R, ptr)
end

###############################################################################
#
#   Resolutions
#
###############################################################################

@doc Markdown.doc"""
    sres{T <: Nemo.RingElem}(I::smodule{T}, max_length::Int)
> Compute a free resolution of the given module $I$ of length up to the given
> maximum length. If `max_length` is set to zero, a full length free
> resolution is computed. Each element of the resolution is itself a module.
"""
function sres(I::smodule{T}, max_length::Int) where T <: Nemo.RingElem
   I.isGB == false && error("Not a Groebner basis ideal")
   R = base_ring(I)
   if max_length == 0
        max_length = nvars(R)
        # TODO: consider qrings
   end
   r, minimal = libSingular.id_sres(I.ptr, Cint(max_length + 1), R.ptr)
   return sresolution{T}(R, r, Bool(minimal))
end

###############################################################################
#
#   Module constructors
#
###############################################################################

function Module(R::PolyRing{T}, vecs::svector{spoly{T}}...) where T <: Nemo.RingElem
   S = elem_type(R)
   return smodule{S}(R, vecs...)
end

function Module(R::PolyRing{T}, id::libSingular.ideal_ptr) where T <: Nemo.RingElem
   S = elem_type(R)
   return smodule{S}(R, id)
end

###############################################################################
#
#   Differential functions
#
###############################################################################

@doc Markdown.doc"""
   jet(M::smodule, n::Int)
> Given a module $M$ this function truncates the generators of $M$
> up to degree $n$.
"""
function jet(M::smodule, n::Int)
      R = base_ring(M)
      ptr = libSingular.id_Jet(M.ptr, Cint(n), R.ptr)
      libSingular.idSkipZeroes(ptr)
      return Module(R, ptr)
end

###############################################################################
#
#   Functions for local rings
#
###############################################################################

@doc Markdown.doc"""
   minimal_generating_set(M::smodule)
> Given a module $M$ in ring $R$ with local ordering, this returns an array
> containing the minimal generators of $M$.
"""
function minimal_generating_set(M::smodule)
   R = base_ring(M)
   if has_global_ordering(R) || has_mixed_ordering(R)
      error("Ring needs local ordering.")
   end
   N = Singular.Module(R, Singular.libSingular.idMinBase(M.ptr, R.ptr))
   return [N[i] for i in 1:ngens(N)]
end


###############################################################################
#
#   Eliminate
#
###############################################################################

@doc Markdown.doc"""
    eliminate(M::smodule, polys::spoly...)
> Given a list of polynomials which are variables, construct the
> the intersection of M with the free module
> where those variables have been eliminated.
"""
function eliminate(M::smodule, polys::spoly...)
   R = base_ring(M)
   p = one(R)
   for i = 1:length(polys)
      !isgen(polys[i]) && error("Not a variable")
      parent(polys[i]) != R && error("Incompatible base rings")
      p *= polys[i]
   end
   ptr = libSingular.id_Eliminate(I.ptr, p.ptr, R.ptr)
   return Module(R, ptr)
end

###############################################################################
#
#   Lift
#
###############################################################################

@doc Markdown.doc"""
    lift(M::smodule, SM::smodule)
> represents the generators of SM in terms of the generators of M
> (Matrix(SM) = Matrix(M)*matrix(T))
"""
function lift(M::smodule, SM::smodule)
   R = base_ring(M)
   ptr = libSingular.id_Lift(M.ptr, SM.ptr, R.ptr)
   return smatrix(R, ptr)
end

###############################################################################
#
#   Modulo
#
###############################################################################

@doc Markdown.doc"""
    modulo(A::smodule, B:smodule)
> represents  A/(A intersect B) (isomorphic to (A+B)/B)
"""
function modulo(A::smodule, B::smodule)
   R = base_ring(A)
   ptr = libSingular.id_Modulo(A.ptr, B.ptr, R.ptr)
   return smodule(R, ptr)
end

