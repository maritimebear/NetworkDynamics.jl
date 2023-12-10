using Test
using Graphs
using NetworkDynamics
import NetworkDynamics: GraphStruct, GraphData, get_vertex, get_edge, get_src_vertex, get_src_edges, get_dst_vertex,
                        get_dst_edges, swap_v_array!, swap_e_array!

# Test get_src_edges() for directed graphs
function get_range(i, ndims)
    # Convenience function to generate array-access indices in test
    stop = i * ndims
    start = max(1, stop - ndims + 1)
    return start:stop
end

@testset "Test GraphData Accessors -- directed graph" begin
    # Following existing testset "Test GraphData Accessors"
    g = wheel_digraph(5)

    ndims_edges = 3
    ndims_vertices = 2

    v_dims = [ndims_vertices for _ in vertices(g)]
    e_dims = [ndims_edges for _ in edges(g)]
    gs = GraphStruct(g, v_dims, e_dims, [:t], [:t])

    v_array = rand(sum(v_dims))
    e_array = rand(sum(e_dims))
    gd = GraphData(v_array, e_array, gs)

    for i in 1:nv(g)
        @test get_vertex(gd, i) == v_array[get_range(i, ndims_vertices)]
    end

    for i in 1:ne(g)
        @test get_edge(gd, i) == e_array[get_range(i, ndims_edges)]
    end

    edgelist = collect(edges(g))
    for (i, edge) in enumerate(edgelist)
        @test get_src_vertex(gd, i) == v_array[get_range(edge.src, ndims_vertices)]
        @test get_dst_vertex(gd, i) == v_array[get_range(edge.dst, ndims_vertices)]
    end

    # Mapping node_idx => Vector{edge_idxs} to find edges entering and leaving each node
    # incidence matrix:
    #   rows => nodes, columns => edges
    #   +1 => edge entering node, -1 => edge leaving node
    edges_in::Dict{Int, Vector{Int}} = Dict(i => findall(==(1), incidence_matrix(g)[i, :])
                                            for i in 1:nv(g)
                                           )
    edges_out::Dict{Int, Vector{Int}} = Dict(i => findall(==(-1), incidence_matrix(g)[i, :])
                                            for i in 1:nv(g)
                                           )
    @assert length(edges_in) == length(edges_out) == nv(g)

    for idx_v in 1:nv(g)
        @test get_src_edges(gd, idx_v) == [e_array[get_range(idx_e, ndims_edges)]
                                           for idx_e in edges_out[idx_v]
                                          ]
        @test get_dst_edges(gd, idx_v) == [e_array[get_range(idx_e, ndims_edges)]
                                           for idx_e in edges_in[idx_v]
                                          ]
    end
end

@testset "Test GraphData Accessors" begin
    g = SimpleGraph(5)
    add_edge!(g, (1, 2))
    add_edge!(g, (1, 4))
    add_edge!(g, (1, 5))
    add_edge!(g, (2, 3))
    add_edge!(g, (2, 4))
    add_edge!(g, (2, 5))
    add_edge!(g, (3, 4))
    add_edge!(g, (3, 5))
    v_dims = [2 for i in vertices(g)]
    e_dims = [2 for i in edges(g)]
    gs = GraphStruct(g, v_dims, e_dims, [:t], [:t])

    v_array = rand(sum(v_dims))
    e_array = rand(sum(e_dims))
    gd = GraphData(v_array, e_array, gs)

    @test get_vertex(gd, 1) == v_array[1:2]
    @test get_vertex(gd, 2) == v_array[3:4]
    @test get_vertex(gd, 3) == v_array[5:6]
    @test get_vertex(gd, 4) == v_array[7:8]
    @test get_vertex(gd, 5) == v_array[9:10]
    @test get_edge(gd, 1) == e_array[1:2]
    @test get_edge(gd, 2) == e_array[3:4]
    @test get_edge(gd, 3) == e_array[5:6]
    @test get_edge(gd, 4) == e_array[7:8]
    @test get_edge(gd, 5) == e_array[9:10]
    @test get_edge(gd, 6) == e_array[11:12]
    @test get_edge(gd, 7) == e_array[13:14]
    @test get_edge(gd, 8) == e_array[15:16]

    @test get_src_vertex(gd, 1) == v_array[1:2]
    @test get_dst_vertex(gd, 1) == v_array[3:4]
    @test get_src_vertex(gd, 8) == v_array[5:6]
    @test get_dst_vertex(gd, 8) == v_array[9:10]

    # TODO: Remove test_throws thingy
    # # Why e_array[i:i+1] instead of e_array[i:i] or [e_array[i]] ?
    # @test_throws ErrorException get_src_edges(gd, 1) == [e_array[1:2], e_array[3:4], e_array[5:6]]
    # @test_throws ErrorException get_src_edges(gd, 3) == [e_array[13:14], e_array[15:16]]

    @test get_dst_edges(gd, 1) == [e_array[2:2], e_array[4:4], e_array[6:6]]
    @test get_dst_edges(gd, 3) == [e_array[7:7], e_array[14:14], e_array[16:16]]
    @test get_dst_edges(gd, 5) == [e_array[5:5], e_array[11:11], e_array[15:15]]

    # Test the swaping of the underlying data
    v_array2 = rand(sum(v_dims))
    e_array2 = rand(sum(e_dims))
    swap_v_array!(gd, v_array2)
    swap_e_array!(gd, e_array2)

    @test get_vertex(gd, 1) == v_array2[1:2]
    @test get_vertex(gd, 2) == v_array2[3:4]
    @test get_vertex(gd, 3) == v_array2[5:6]
    @test get_vertex(gd, 4) == v_array2[7:8]
    @test get_vertex(gd, 5) == v_array2[9:10]
    @test get_edge(gd, 1) == e_array2[1:2]
    @test get_edge(gd, 2) == e_array2[3:4]
    @test get_edge(gd, 3) == e_array2[5:6]
    @test get_edge(gd, 4) == e_array2[7:8]
    @test get_edge(gd, 5) == e_array2[9:10]
    @test get_edge(gd, 6) == e_array2[11:12]
    @test get_edge(gd, 7) == e_array2[13:14]
    @test get_edge(gd, 8) == e_array2[15:16]

    # it should not be possible to change the type of v or e array!
    v_array3 = rand(Int, sum(v_dims))
    e_array3 = rand(Int, sum(e_dims))
    @test_throws MethodError swap_v_array!(gd, v_array3)
    @test_throws MethodError swap_e_array!(gd, e_array3)
end

@testset "test edgedata and vertex data indexing" begin
    using NetworkDynamics: GraphDataBuffer, VertexData, EdgeData
    gdb = GraphDataBuffer(collect(1:15), collect(1:15))
    vd = VertexData{typeof(gdb), Integer}(gdb, 5, 5)
    ed = EdgeData{typeof(gdb), Integer}(gdb, 10, 4)

    @test vd[begin] == 6
    @test vd[end] == 10
    @test ed[begin] == 11
    @test ed[end] == 14

    ed[1:2] = [1,2]
    @test ed[1] == 1
    @test ed[2] == 2
    ed[1:2] .= [4,5]
    @test ed[1] == 4
    @test ed[2] == 5
    ed[1:2] = 9:10
    @test ed[1] == 9
    @test ed[2] == 10

    ed[1:2] = [1,2,3,4][[2,3]]
    @test ed[1:2] == [2,3]

    vd[1:2] = [1,2]
    @test vd[1] == 1
    @test vd[2] == 2
    vd[1:2] .= [4,5]
    @test vd[1] == 4
    @test vd[2] == 5
    vd[1:2] = 9:10
    @test vd[1] == 9
    @test vd[2] == 10

    vd[1:2] = [1,2,3,4][[2,3]]
    @test vd[1:2] == [2,3]
end
