# Test DirectedODEVertex by accessing both incoming and outgoing edges
# Following NetworkDynamics v0.4.0 tutorials as these use incoming and outgoing edges at each vertex

import Graphs as gr
import GLMakie, GraphMakie # TODO: Cleanup
import Plots as plt # TODO: Cleanup
import NetworkDynamics as nd
import DifferentialEquations as de

# Diffusion tutorial
function diffusionedge!(e, v_s, v_d, p, t)
    e .= v_s - v_d
    return nothing
end

function diffusionvertex!(dv, v, edges_in, edges_out, p, t)
    # dv .= 0.0
    # for e in edges_in # ie. this node is the destination
    #     dv .+= e
    # end
    # for e in edges_out # ie. this node is the source
    #     dv .-= e
    # end
    dv .= sum(map(e -> e[1], edges_in)) - sum(map(e -> e[1], edges_out))
        # Access underlying value from NetworkDynamics wrapper structs

    return nothing
end

n_nodes = 20
degree = 4
graph_isdirected = true
timespan = (0.0, 4.0)


g = gr.barabasi_albert(n_nodes, degree, is_directed=graph_isdirected)
edge_coupling = Dict(true => :directed,
                     false => :undefined) # graph directivity => edge coupling type


# display(GraphMakie.graphplot(g, ilabels=repr.(1:gr.nv(g)), elabels=repr.(1:gr.ne(g)))) # TODO: Cleanup

vertexfn = nd.DirectedODEVertex(f=diffusionvertex!, dim=1)
edgefn = nd.StaticEdge(f=diffusionedge!, dim=1, coupling=edge_coupling[graph_isdirected])

nd_fn = nd.network_dynamics(vertexfn, edgefn, g)
sol_init = randn(n_nodes) # Normal distribution, mean=0, sd=1
prob = de.ODEProblem(nd_fn, sol_init, timespan)
sol = de.solve(prob, de.Tsit5())

display(plt.plot(sol, vars=nd.syms_containing(nd_fn, "v"))) # TODO: Cleanup


