
function [edge_count_matrix, maximum_profit, fail_flag] = network_flow(edge_matrix, upper_bound_matrix, lower_bound_matrix, costs_matrix, sinks, sources)
    % Returns a matrix where A-B is the amount on the edge from A -> B



    [edges, edge_upper_bound, edge_lower_bound, edge_cost] = graph_matrix_to_vector(edge_matrix, upper_bound_matrix, lower_bound_matrix, costs_matrix); 
    
    n = size(edge_matrix, 1); 
    edge_count = size(edges, 2); 

    Aeq = zeros([n, edge_count]); 
    beq = zeros([n, 1]);

    for edge_column = 1 : edge_count
        edge_start = edges(1, edge_column);
        if (~ismember(edge_start, sources))
            Aeq(edge_start, edge_column) = -1;
        end
        
        edge_end   = edges(2, edge_column);
        if (~ismember(edge_end, sinks)) 
            Aeq(edge_end, edge_column) = 1; 
        end
    end
    % disp('Aeq')
    % disp(sum(Aeq, 2))
    % disp(Aeq)
    % disp(rank(Aeq))
    % disp('beq')
    % disp(size(beq))
    % disp(size(edge_cost))
    % disp('Upper Bound')
    % disp(edge_upper_bound)
    % disp('Lower Bound')
    % disp(edge_lower_bound)
    options = optimset('display','off');
    % disp(edge_cost)
    [counts_on_edges, minimum_negative_profit, fail_flag] = linprog(-edge_cost, [], [], Aeq, beq, edge_lower_bound, edge_upper_bound, options);
    maximum_profit = -minimum_negative_profit; 
    % disp(counts_on_edges)
    if (fail_flag == 1)
        edge_count_matrix = vector_to_graph_matrix(n, edges, counts_on_edges); 
    else 
        edge_count_matrix = zeros(); 
    end
end


function [edges, edge_upper_bound, edge_lower_bound, edge_cost] = graph_matrix_to_vector(edge_matrix, upper_bound_matrix, lower_bound_matrix, costs_matrix)
    n = size(edge_matrix, 1);

    edges = []; % Get the order of the edges flattened
    for start_node = 1 : n 
        for end_node = 1 : n
            if (edge_matrix(start_node, end_node) == 1)
                edges = [edges, [start_node; end_node]];
            end
        end
    end
    
    edge_count = size(edges, 2); 
    
    edge_upper_bound = [];
    for edge_column = 1 : edge_count
        edge_upper_bound = [edge_upper_bound, upper_bound_matrix(edges(1, edge_column), edges(2, edge_column))];
    end 

    edge_lower_bound = [];
    for edge_column = 1 : edge_count
        edge_lower_bound = [edge_lower_bound, lower_bound_matrix(edges(1, edge_column), edges(2, edge_column))];
    end 

    edge_cost = [];
    for edge_column = 1 : edge_count
        edge_cost = [edge_cost, costs_matrix(edges(1, edge_column), edges(2, edge_column))];
    end 
end

function [graph_matrix] = vector_to_graph_matrix(n, edges, counts_on_edges)
    
    graph_matrix = zeros([n, n]);
    edge_count = size(edges, 2);
    disp(n)
    disp(edge_count);
    disp(edges)
    % disp(size(edges, 2))
    for index = 1 : edge_count
        % disp(index)
        edge_start = edges(1, index); 
        edge_end   = edges(2, index);
        graph_matrix(edge_start, edge_end) = counts_on_edges(index);
    end
end