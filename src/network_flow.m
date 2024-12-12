
function edges = network_flow(edge_matrix, upper_bound, lower_bound, costs)
    % Returns a matrix where A-B is the amount on the edge from A -> B



    [edges, edge_upper_bound, edge_lower_bound, edge_cost] = graph_matrix_to_vector(edge_matrix, upper_bound, lower_bound, costs); 
    
    n = size(edge_matrix, 1); 
    edge_count = size(edges, 2); 

    Aeq = zeros([n, edge_count]); 
    beq = zeros(n);

    for edge_column = 1 : edge_count
        edge_start = edges(edge_column, 1);
        edge_end   = edges(edge_column, 2); 

        Aeq(edge_start, edge_column) = -1; 
        Aeq(edge_end  , edge_start)  =  1; 
    end

    options = optimset('display','off');
    counts_on_edges = linprog(-edge_cost, [], [], Aeq, beq, edge_lower_bound, edge_upper_bound, options);

    vector_to_graph_matrix(edges, counts_on_edges); 
end


function [edges, edge_upper_bound, edge_lower_bound, edge_cost] = graph_matrix_to_vector(edge_matrix, upper_bound, lower_bound, costs)
    n = size(edge_matrix, 1);

    edges = []; % Get the order of the edges flattened
    for start_node = 1 : n 
        for end_node = 1 : n
            if (edge_matrix(start_node, end_node) == 1)
                edges = [edges, [start_node; end_node]];
            end
        end
    end

    edge_upper_bound = [];
    for edge_column = 1 : n 
        edge_upper_bound = [edge_upper_bound, upper_bound(edges(edge_column, :))];
    end 

    edge_lower_bound = [];
    for edge_column = 1 : n 
        edge_lower_bound = [edge_lower_bound, lower_bound(edges(edge_column, :))];
    end 

    edge_cost = []; 
    for edge_column = 1 : n 
        edge_costs = [edge_costs, -costs(edges(edge_column, :))];
    end 
end

function [graph_matrix] = vector_to_graph_matrix(edges, counts_on_edges)
    n = size(edges, 2);
    graph_matrix = zeros([n, n]);
    for index = 1 : n 
        graph_matrix(edges(index, :)) = counts_on_edges(index);
    end
end