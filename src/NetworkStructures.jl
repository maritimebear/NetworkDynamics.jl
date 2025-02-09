#
# This file contains the logic that calculate the index structures
# and data access structs that Network Dynamics makes use of.
#
# The key structure is the GraphData structure that allows accessing data on
# vertices and edges of the graph in an efficient manner. The neccessary indices
# are precomputed in GraphStructure.


using Graphs
using LinearAlgebra

const Idx = UnitRange{Int}

"""
    create_offsets(dims; counter=0)

Create offsets for stacked array of dimensions dims
"""
function create_offsets(dims; counter=0)::Vector{Int}
    offs = [1 for dim in dims]
    for (i, dim) in enumerate(dims)
        offs[i] = counter
        counter += dim
    end
    offs
end

"""
    create_idxs(offs, dims)

Create indexes for stacked array of dimensions dims using the offsets offs
"""
function create_idxs(offs, dims)::Vector{Idx}
    idxs = [1+off:off+dim for (off, dim) in zip(offs, dims)]
end

"""
    GraphStruct(g, v_dims, e_dims, v_syms, e_syms)

This struct holds the offsets and indices for all relevant aspects of the graph
The assumption is that there will be two arrays, one for the vertex variables
and one for the edge variables.

The graph structure is encoded in the source and destination relationships s_e
and d_e. These are arrays that hold the node that is the source/destination of
the indexed edge. Thus ``e_i = (s_e[i], d_e[i])``
"""
struct GraphStruct

    num_v::Int                                 # number of vertices
    num_e::Int                                 # number of edges

    v_dims::Vector{Int}                        # dimensions per vertex
    e_dims::Vector{Int}                        # dimensions per edge

    v_syms::Vector{Symbol}                     # symbol per vertex
    e_syms::Vector{Symbol}                     # symbol per edge

    dim_v::Int                                 # total vertex dimensions
    dim_e::Int                                 # total edge dimensions

    s_e::Vector{Int}                           # src-vertex idx per edge
    d_e::Vector{Int}                           # dst-vertex idx per edge

    s_v::Array{Vector{Int}}                    # indices of source edges per vertex
    d_v::Array{Vector{Int}}                    # indices of destination edges per vertex

    v_offs::Vector{Int}                        # linear offset per vertex
    e_offs::Vector{Int}                        # linear offset per edge

    v_idx::Vector{Idx}                         # lin. idx-range per vertex
    e_idx::Vector{Idx}                         # lin. idx-range per edge

    s_e_offs::Vector{Int}                      # offset of src-vertex per edge
    d_e_offs::Vector{Int}                      # offset of dst-vertex per edge

    s_e_idx::Vector{Idx}                       # idx-range of src-vertex per edge
    d_e_idx::Vector{Idx}                       # idx-range of dst-vertex per edge

    # index of node -> vector of edges, represented as tuples:
    #   edge: (index of source node, index of destination node)
    dst_edges_dat::Vector{Vector{Tuple{Int,Int}}} # edges entering node
    src_edges_dat::Vector{Vector{Tuple{Int, Int}}} # edges leaving node
end
function GraphStruct(g, v_dims, e_dims, v_syms, e_syms)
    num_v = nv(g)
    num_e = ne(g)

    s_e = src.(edges(g)) # Indices of source-nodes of all edges
    d_e = dst.(edges(g)) # Indices of destination-nodes of all edges

    # Initialize Vector of empty Vector{Int} for the edge indices per vertex
    s_v = [Int[] for i in 1:num_v] # Indices of edges leaving each node
    d_v = [Int[] for i in 1:num_v] # Indices of edges entering each node
    for i in 1:num_e
        push!(s_v[s_e[i]], i)
        push!(d_v[d_e[i]], i)
    end


    # Vectors containing number of indices to be offset for each node/edge in the state vector,
    # accounting for its number of dimensions
    v_offs = create_offsets(v_dims)
    e_offs = create_offsets(e_dims)

    # Indices to access the state vector, accounting for the offsets from above
    v_idx = create_idxs(v_offs, v_dims)
    e_idx = create_idxs(e_offs, e_dims)

    # Offsets of source- and destination-nodes for each edge
    s_e_offs = [v_offs[s_e[i_e]] for i_e in 1:num_e]
    d_e_offs = [v_offs[d_e[i_e]] for i_e in 1:num_e]

    # State-vector-indices of source- and destination-nodes for each edge
    s_e_idx = [v_idx[s_e[i_e]] for i_e in 1:num_e]
    d_e_idx = [v_idx[d_e[i_e]] for i_e in 1:num_e]

    edge_access_type::DataType = Vector{Tuple{Int, Int}} # For convenience and type-checking
    dst_edges_dat = Vector{edge_access_type}(undef, nv(g)) # For each node, vector of incoming edges
    src_edges_dat = Vector{edge_access_type}(undef, nv(g)) # Outgoing edges for each node

    if is_directed(g)
        for i_v in 1:nv(g) # for each node
            edgesin_offsdim::edge_access_type = edge_access_type(undef, 0) # Empty Vector{Tuple{Int, Int}}
            edgesout_offsdim::edge_access_type = edge_access_type(undef, 0)

            # Populating vectors using loops to preserve eltypes in case d_v[i] or s_v[i] are empty
            # Using map()/comprehension seems to change eltype to Tuple{Any, Any} if applied to an empty collection?
            for i_e in d_v[i_v] # for each edge entering the current node
                push!(edgesin_offsdim, (e_offs[i_e], e_dims[i_e]))
            end
            for i_e in s_v[i_v] # for each edge leaving the current node
                push!(edgesout_offsdim, (e_offs[i_e], e_dims[i_e]))
            end
            dst_edges_dat[i_v] = edgesin_offsdim
            src_edges_dat[i_v] = edgesout_offsdim
        end # for each node

    else # ie. g is non-directed
        for i_v in 1:nv(g)
        edgesin_offsdim::edge_access_type = edge_access_type(undef, 0) # Empty Vector{Tuple{Int, Int}}
        edgesout_offsdim::edge_access_type = edge_access_type(undef, 0)
            # dims is a multiple of 2 for SimpleGraph by design of VertexFunction
            for i_e in d_v[i_v]
                push!(edgesin_offsdim, (e_offs[i_e], e_dims[i_e] / 2))
                push!(edgesout_offsdim, (e_offs[i_e] + e_dims[i_e] / 2, e_dims[i_e] / 2))
            end
            for i_e in s_v[i_v]
                push!(edgesin_offsdim, (e_offs[i_e] + e_dims[i_e] / 2, e_dims[i_e] / 2))
                push!(edgesout_offsdim, (e_offs[i_e], e_dims[i_e] / 2))
            end
            dst_edges_dat[i_v] = edgesin_offsdim
            src_edges_dat[i_v] = edgesout_offsdim
        end # for each node

    end # if

    GraphStruct(num_v,
                num_e,
                v_dims,
                e_dims,
                v_syms,
                e_syms,
                sum(v_dims),
                sum(e_dims),
                s_e,
                d_e,
                s_v,
                d_v,
                v_offs,
                e_offs,
                v_idx,
                e_idx,
                s_e_offs,
                d_e_offs,
                s_e_idx,
                d_e_idx,
                dst_edges_dat,
                src_edges_dat)
end


import Base.getindex, Base.setindex!, Base.length, Base.IndexStyle, Base.size, Base.eltype, Base.dataids

"""
    struct EdgeData{GDB, elE} <: AbsstractVector{elE}

The EdgeData object behaves like an array and allows access to the underlying
data of a specific edge (like a View). Unlike a View, the parent array is stored
in a mutable GraphDataBuffer object and can be swapped.
"""
struct EdgeData{GDB,elE} <: AbstractVector{elE}
    gdb::GDB
    idx_offset::Int
    len::Int
end

Base.@propagate_inbounds function getindex(e_dat::EdgeData, idx::Int)
    e_dat.gdb.e_array[idx + e_dat.idx_offset]
end

Base.@propagate_inbounds function setindex!(e_dat::EdgeData, x, idx::Int)
    e_dat.gdb.e_array[idx + e_dat.idx_offset] = x
    nothing
end

@inline function Base.length(e_dat::EdgeData)
    e_dat.len
end

@inline function Base.size(e_dat::EdgeData)
    (e_dat.len,)
end

@inline function Base.eltype(e_dat::EdgeData{GDB,elE}) where {GDB,elE}
    elE
end

Base.IndexStyle(::Type{<:EdgeData}) = IndexLinear()

@inline Base.dataids(e_dat::EdgeData) = dataids(e_dat.gdb.e_array)

"""
    struct VertexData{GDB, elV} <: AbsstractVector{elV}

The VertexData object behaves like an array and allows access to the underlying
data of a specific vertex (like a View). Unlike a View, the parent array is stored
in a mutable GraphDataBuffer object and can be swapped.
"""
struct VertexData{GDB,elV} <: AbstractVector{elV}
    gdb::GDB
    idx_offset::Int
    len::Int
end

Base.@propagate_inbounds function getindex(v_dat::VertexData, idx::Int)
    v_dat.gdb.v_array[idx + v_dat.idx_offset]
end

Base.@propagate_inbounds function setindex!(v_dat::VertexData, x, idx::Int)
    v_dat.gdb.v_array[idx + v_dat.idx_offset] = x
    nothing
end

@inline function Base.length(v_dat::VertexData)
    v_dat.len
end

@inline function Base.size(e_dat::VertexData)
    (e_dat.len,)
end

@inline function Base.eltype(e_dat::VertexData{G,elV}) where {G,elV}
    elV
end

Base.IndexStyle(::Type{<:VertexData}) = IndexLinear()

@inline Base.dataids(v_dat::VertexData) = dataids(v_dat.gdb.v_array)


"""
    mutable struct GraphDataBuffer{Tv, Te}

Is a composite type which holds two Arrays for the underlying data of a graph.
The type is mutable, therfore the v_array and e_array can be changed.
"""
mutable struct GraphDataBuffer{Tv,Te}
    v_array::Tv
    e_array::Te
end

"""
    GraphData{GDB, elV, elE}

The GraphData object contains a reference to the GraphDataBuffer object and to all the
view-like EdgeData/VertexData objects. It is used to access the underlying linear data
of a graph in terms of edges and vertices. The underlying data kann be swapped using the

    swap_v_array
    swap_e_array

methods.
The data for specific edges/vertices can be accessed using the

    get_vertex, get_edge
    get_src_vertex, get_dst_vertex
    get_src_edges, get_dst_edges

methods.
"""
struct GraphData{GDB,elV,elE}
    gdb::GDB
    v::Vector{VertexData{GDB,elV}}
    e::Vector{EdgeData{GDB,elE}}
    v_s_e::Vector{VertexData{GDB,elV}} # the vertex that is the source of e
    v_d_e::Vector{VertexData{GDB,elV}} # the vertex that is the destination of e
    dst_edges::Vector{Vector{EdgeData{GDB,elE}}} # the half-edges that have v as destination
    src_edges::Vector{Vector{EdgeData{GDB,elE}}} # the half-edges that have v as source
end

function GraphData(v_array::Tv, e_array::Te, gs::GraphStruct; global_offset=0) where {Tv,Te}
    gdb = GraphDataBuffer{Tv,Te}(v_array, e_array)
    GDB = typeof(gdb)
    elV = eltype(v_array)
    elE = eltype(e_array)
    v = [VertexData{GDB,elV}(gdb, offset + global_offset, dim) for (offset, dim) in zip(gs.v_offs, gs.v_dims)]
    e = [EdgeData{GDB,elE}(gdb, offset + global_offset, dim) for (offset, dim) in zip(gs.e_offs, gs.e_dims)]
    v_s_e = [VertexData{GDB,elV}(gdb, offset + global_offset, dim)
             for (offset, dim) in zip(gs.s_e_offs, gs.v_dims[gs.s_e])]
    v_d_e = [VertexData{GDB,elV}(gdb, offset + global_offset, dim)
             for (offset, dim) in zip(gs.d_e_offs, gs.v_dims[gs.d_e])]
    dst_edges = [[EdgeData{GDB,elE}(gdb, offset + global_offset, dim) for (offset, dim) in in_edge]
                 for in_edge in gs.dst_edges_dat]
    src_edges = [[EdgeData{GDB,elE}(gdb, offset + global_offset, dim) for (offset, dim) in out_edge]
                 for out_edge in gs.src_edges_dat]
    GraphData{GDB,elV,elE}(gdb, v, e, v_s_e, v_d_e, dst_edges, src_edges)
end


#= In order to manipulate initial conditions using this view of the underlying
array we provide view functions that give access to the arrays. =#

export view_v
export view_e

function view_v(gd::GraphData, gs::GraphStruct, sym="")
    v_idx = [i for (i, s) in enumerate(gs.v_syms) if occursin(string(sym), string(s))]
    view(gd.gdb.v_array, v_idx)
end

function view_e(gd::GraphData, gs::GraphStruct, sym="")
    e_idx = [i for (i, s) in enumerate(gs.e_syms) if occursin(string(sym), string(s))]
    view(gd.gdb.e_array, e_idx)
end


function view_v(nd, x, p, t, sym="")
    gd = nd(x, p, t, GetGD)
    gs = nd(GetGS)
    v_idx = [i for (i, s) in enumerate(gs.v_syms) if occursin(string(sym), string(s))]
    view(gd.gdb.v_array, v_idx)
end

function view_e(nd, x, p, t, sym="")
    gd = nd(x, p, t, GetGD)
    gs = nd(GetGS)
    e_idx = [i for (i, s) in enumerate(gs.e_syms) if occursin(string(sym), string(s))]
    view(gd.gdb.e_array, e_idx)
end

export swap_v_array!, swap_e_array!

"""
    swap_v_array!(gd:GraphData, array)

Swaps the underlying vertex data array of an GraphData type with a new one.
"""
@inline function swap_v_array!(gd::GraphData{GDB,elV,elE}, array::AbstractArray{elV}) where {GDB,elV,elE}
    gd.gdb.v_array = array
end

"""
    swap_e_array!(gd:GraphData, array)

Swaps the underlying edge data array of an GraphData type with a new one.
"""
@inline function swap_e_array!(gd::GraphData{GDB,elV,elE}, array::AbstractArray{elE}) where {GDB,elV,elE}
    gd.gdb.e_array = array
end

export get_vertex, get_edge, get_src_vertex, get_dst_vertex, get_src_edges, get_dst_edges

"""
    get_vertex(gd::GraphData, idx::Int) -> View

Returns a view-like access to the underlying data of the i-th vertex.
"""
@inline get_vertex(gd::GraphData, i::Int) = gd.v[i]

"""
    get_edge(gd::GraphData, idx::Int) -> View

Returns a view-like access to the underlying data of the i-th edge.
"""
@inline get_edge(gd::GraphData, i::Int) = gd.e[i]

"""
    get_src_vertex(gd::GraphData, idx::Int) -> View

Returns a view-like access to the underlying data of source vertex of the i-th edge.
"""
@inline get_src_vertex(gd::GraphData, i::Int) = gd.v_s_e[i]

"""
    get_dst_vertex(gd::GraphData, idx::Int) -> View

Returns a view-like access to the underlying data of destination vertex of the i-th edge.
"""
@inline get_dst_vertex(gd::GraphData, i::Int) = gd.v_d_e[i]

"""
    get_src_edges(gd::GraphData, i::Int)

Returns a Vector of view-like accesses to all the (half-)edges that have the i-th vertex as source (for directed graphs these are the out-edges).
"""
@inline get_src_edges(gd::GraphData, i::Int) = gd.src_edges[i]

"""
    get_dst_edges(gd::GraphData, i::Int)

Returns a Vector of view-like accesses to all the (half-)edges that have the i-th vertex as destination (for directed graphs these are the in-edges).
"""
@inline get_dst_edges(gd::GraphData, i) = gd.dst_edges[i]




export GetGD
export GetGS

"""
    struct GetGD

This type is used to dispatch the network dynamics functions to provide
access to the underlying GraphData object.
"""
struct GetGD end

"""
    struct GetGS

This type is used to dispatch the network dynamics functions to provide
access to the underlying GraphStruct object.
"""
struct GetGS end


#= Experimental and untested: Wrap a solution object so we get back a GraphData
object at every time. =#
export ND_Solution

struct ND_Solution
    nd
    p
    sol
end
function (nds::ND_Solution)(t)
    nds.nd(nds.sol(t), nds.p, t, GetGD)
end
