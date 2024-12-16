
%%%
%%% MODEL CONSTANTS
%%%

%% HOURS
HOURS_OPEN = 3; 
TICKET_TIER_PRICES = [1, 2, 1]; % Prices to get in every 4 hrs
TOTAL_PERSON_CAP   = 1000;

%% BAR A
SMALL_DRINK_PRICES = 1 * ones(HOURS_OPEN);
MEDIUM_DRINK_PRICES = 2 * ones(HOURS_OPEN); 
LARGE_DRINK_PRICES = 3 * ones(HOURS_OPEN); 

BAR_A_SITTING_CAPACITY = 5; 
BAR_A_STANDING_CAPACITY = BAR_A_SITTING_CAPACITY; 

%% BAR B 
MEAL_PRICES = 5 * ones(HOURS_OPEN); 

BAR_B_CAPACITY = 25; 

%% DANCE FLOOR
DANCE_COST =  30 * ones(HOURS_OPEN);

%%%
%%% BUILD MODEL 
%%%

% Creates a triple nested map, which has 
% indexMap := [hour(int)]["bar a" | "bar b" | "dance floor"]["start" | "end"] = index | 
%             ["tier 1 ticket" | "tier 2 ticket" | "tier 3 ticket" | "exit" | "entrance" | "source"] = index
function [index_map, num_indexes] = createMap(hours_open)
    index_counter = 1; 
    location_options = ["bar a", "bar b", "dance floor"];
    at_hour_options = ["start", "end"]; 

    index_map = dictionary(); 
    for hour = 1 : hours_open 
        for location = location_options 
            for at_hour = at_hour_options
                index_map({[hour, location, at_hour]}) = index_counter;
                index_counter = index_counter + 1; 
            end
        end
    end

    other_nodes = ["tier 1 ticket", "tier 2 ticket", "tier 3 ticket", "exit", "entrance", "source"];

    for node = other_nodes
        index_map({node}) = index_counter; 
        index_counter = index_counter + 1;
    end

    num_indexes = index_counter - 1;
end



% Creates the adjacency matrix
function [index_map, edge_matrix, upper_bound_matrix, lower_bound_matrix, costs_matrix] = ...
    buildGraph(hours_open, ticket_tier_prices, ....
               small_drink_prices, medium_drink_prices, large_drink_prices, bar_a_sitting_capacity, bar_a_standing_capacity, ... 
               meal_prices, bar_b_capacity, ... 
               dance_costs, person_cap)
    
    location_options = ["bar a", "bar b", "dance floor"];
    at_hour_options = ["start", "end"]; 
    other_nodes = ["tier 1 ticket", "tier 2 ticket", "tier 3 ticket", "exit", "entrance", "source"];
    
    [index_map, num_indexes] = createMap(hours_open);
    
    edge_matrix        = zeros([num_indexes, num_indexes]);
    upper_bound_matrix = zeros([num_indexes, num_indexes]); 
    lower_bound_matrix = zeros([num_indexes, num_indexes]);
    costs_matrix       = zeros([num_indexes, num_indexes]);

    function addEdge(edge_start, edge_end, upper_bound, cost) 
        edge_matrix(edge_start, edge_end) = 1; 
        upper_bound_matrix(edge_start, edge_end) = upper_bound; 
        costs_matrix(edge_start, edge_end) = cost; 
    end

    % Connect the start and end nodes
    for hour = 1 : hours_open
        for location = location_options 
            start_index = index_map({[hour, location, "start"]}); 
            end_index = index_map({[hour, location, "end"]});

            % edge_matrix(start_index, end_index) = 1; 

            if location == "bar a"
                addEdge(start_index, end_index, bar_a_sitting_capacity, medium_drink_prices(hour)); 
            elseif location == "bar b"
                addEdge(start_index, end_index, bar_b_capacity, meal_prices(hour)); 
            elseif location == "dance floor"
                addEdge(start_index, end_index, inf, -dance_costs(hour)); 
            end
        end
    end

    % Entering and exiting bar A
    for hour = 1 : hours_open
        start_index = index_map({[hour, "bar a", "start"]}); 
        
        % From Staying in the bar
        if hour > 1
            previous_bar_a = index_map({[hour - 1, "bar a", "end"]}); 
            % disp([start_index, previous_bar_a])
            addEdge(previous_bar_a, start_index, inf, 0); 
        end
        
        % From entering from the dance floor
        if hour > 1
            previous_dance_floor = index_map({[hour - 1, "dance floor", "end"]});  
            addEdge(previous_dance_floor, start_index, inf, 0); 
        end 
        
        

        % Grabbing a drink and leaving immediately 
        current_dance_floor = index_map({[hour, "dance floor", "start"]});
        addEdge(start_index, current_dance_floor, bar_a_standing_capacity, small_drink_prices(hour));

        % Leaving the bar to go do the dance floor
        end_index   = index_map({[hour, "bar a", "end"]}); 
        if hour < hours_open
            next_dance_floor = index_map({[hour + 1, "dance floor", "start"]});
            addEdge(end_index, next_dance_floor, inf, small_drink_prices(hour));
        else 
            % at the end of the hour, exit the club if at the bar
            exit_index = index_map({"exit"});
            addEdge(end_index, exit_index, inf, 0);
        end 
        
    end

    % Entering and exiting bar b
    for hour = 1 : hours_open
        start_index = index_map({[hour, "bar b", "start"]}); 
        
        % From entering from the dance floor
        if hour ~= 1
            previous_dance_floor = index_map({[hour - 1, "dance floor", "end"]});  
            addEdge(previous_dance_floor, start_index, inf, 0); 
        end 

        end_index = index_map({[hour, "bar b", "end"]}); 
        if hour ~= hours_open
            next_dance_floor = index_map({[hour + 1, "dance floor", "start"]});
            addEdge(end_index, next_dance_floor, inf, 0);
        else
            % at the end of the hour, exit the club if at the bar
            exit_index = index_map({"exit"});
            addEdge(end_index, exit_index, inf, 0);
        end
    end

    % Staying on the dance floor 
    for hour = 1 : hours_open
        
        % From entering via the ticket 
        start_index = index_map({[hour, "dance floor", "start"]}); 
        ticket_range = floor(hours_open ./ size(ticket_tier_prices, 1));
        ticket_tier  = floor((hour - 1) ./ ticket_range) + 1; 
        tier_index   = index_map({other_nodes(ticket_tier)});
        addEdge(tier_index, start_index, inf, ticket_tier_prices(ticket_tier));

        end_index = index_map({[hour, "dance floor", "end"]}); 
        if hour ~= hours_open
            next_dance_floor = index_map({[hour + 1, "dance floor", "start"]});
            addEdge(end_index, next_dance_floor, inf, 0);
        else
            % at the end of the hour, exit the club if at the bar
            exit_index = index_map({"exit"});
            addEdge(end_index, exit_index, inf, 0);
        end
    end

    % Buying a ticket at the entrance
    tickets = ["tier 1 ticket", "tier 2 ticket", "tier 3 ticket"];
    source_index = index_map({"source"});
    entrance_index = index_map({"entrance"});
    addEdge(source_index, entrance_index, person_cap, 0); 
    for ticket = tickets 
        ticket_index = index_map({ticket});
        addEdge(entrance_index, ticket_index, inf, 0);
    end

    % From entering via the ticket 
    num_tickets = size(tickets, 2);
    ticket_range_size = floor(hours_open ./ num_tickets);
    for ticket_num = 1 : num_tickets
        ticket = tickets(ticket_num);
        ticket_index = index_map({ticket});
        for hour = (ticket_num - 1) * ticket_range_size + 1: ticket_num * ticket_range_size
            for location = location_options
                ticket_price = ticket_tier_prices(ticket_num);
                % disp([hour, location, "start"])
                location_index = index_map({[hour, location, "start"]});
                if location == "bar a"
                    ticket_price = ticket_price + large_drink_prices(hour);
                end
                addEdge(ticket_index, location_index, inf, ticket_price);
            end
        end
    end

end

function [solution, maximum_profit, has_solved, index_map, edge_matrix] = solveModel(hours_open, ticket_tier_prices, ....
    small_drink_prices, medium_drink_prices, large_drink_prices, bar_a_sitting_capacity, bar_a_standing_capacity, ... 
    meal_prices, bar_b_capacity, ... 
    dance_costs, person_cap)
   
    [index_map, edge_matrix, upper_bound_matrix, lower_bound_matrix, costs_matrix] = ...
        buildGraph(hours_open, ticket_tier_prices, ....
            small_drink_prices, medium_drink_prices, large_drink_prices, bar_a_sitting_capacity, bar_a_standing_capacity, ... 
            meal_prices, bar_b_capacity, ... 
            dance_costs, person_cap);
    
    sinkNodeNames    = ["exit"];
    sourceNodeNames  = ["source"];
    sinkNodes        = arrayfun(@(x) index_map({x}), sinkNodeNames);
    sourceNodes      = arrayfun(@(x) index_map({x}), sourceNodeNames);
    [solution, maximum_profit, fail_flag] = network_flow(edge_matrix, upper_bound_matrix, lower_bound_matrix, costs_matrix, sinkNodes, sourceNodes);
    has_solved = false; 
    switch fail_flag
        case 3 
            fprintf('The solution is feasible with respect to the relative ConstraintTolerance tolerance, but is not feasible with respect to the absolute tolerance.\n');
        case 1 
            has_solved = true;
        case 0
            fprintf('Number of iterations exceeded options.MaxIterations or solution time in seconds exceeded options.MaxTime.\n');
        case -2
            fprintf('No feasible point was found.\n');
        case -3
            fprintf('Problem is unbounded.\n');
        case -4
            fprintf('NaN value was encountered during execution of the algorithm.\n');
        case -5
            fprintf('Both primal and dual problems are infeasible.\n');
        case -7
            fprintf('Search direction became too small. No further progress could be made.\n');
        case -9
            fprintf('Solver lost feasibility.\n');
    end
end

function displayResult(solution, index_map, edge_matrix, hours_open)
    % disp(index_map)

    % disp(solution)
    % index_to_node = dictionary();
    % index_keyset = keys(index_map);
    % for key_index = 1 : length(index_keyset)
    %     key = index_keyset(key_index);
    %     value = index_map(key);
    %     index_to_node(value) = key;
    % end 

    function displayText(position, text_string)
        h = text(position(1), position(2), text_string);
        set(h, 'Color','k','FontSize', 8, 'FontWeight', 'bold'); hold on
    end

    function getTotalTickets() 
        tickets = ["tier 1 ticket", "tier 2 ticket", "tier 3 ticket"];
        ticket_indices = arrayfun(@(x) index_map({x}), tickets);
        ticket_total_sold = sum(solution(ticket_indices, : ));
        for index = 1 : size(tickets, 2) 
            fprintf('%s: %d\n', tickets(index), ticket_total_sold(index)); 
        end
    end

    function displayGraph() 
        locations = ["bar a", "dance floor", "bar b"]; 
        
        % fprintf('hours: %d\n', hours_open);
        nodes_map = dictionary();
        nodes     = []; 
        
        function addNodeToGraph(identifier, position, label) 
            nodes = [nodes ; position];
            nodes_map(index_map({identifier})) = size(nodes, 1);
            displayText(position, label);
        end

        % Draw the time and hours
        for hour = 1 : hours_open
            displayText([0.5, hour], sprintf('Start Hour: %d', hour));
            displayText([0.5, hour + 0.5], sprintf('End Hour: %d', hour));
        end

        for location_index = 1 : length(locations) 
            displayText([location_index, hours_open + 0.75], locations(location_index));
        end

        for hour = 1 : hours_open
            
            for location_index = 1 : length(locations)
                % disp('node')
                location = locations(location_index);
                start_node_position = [hour, location_index]; 
                end_node_position   = [hour, location_index + 0.5];

                addNodeToGraph([hour, location, "start"], start_node_position, ""); 
                addNodeToGraph([hour, location, "end"], end_node_position, ""); 

                % nodes = [nodes ; start_node_position ; end_node_position];
                % displayText(start_node_position, sprintf('hour: %d, location: %s', hour, location)); 
                % displayText(end_node_position, sprintf('hour: %d, location: %s', hour, location))
                % % h = text(hour, location_index, sprintf('hour: %d, location: %s', hour, location));
                % % set(h, 'Color','k','FontSize', 4, 'FontWeight', 'bold'); hold on
                % % h = text(hour, location_index + 0.5, sprintf('hour: %d, location: %s', hour, location));
                % % set(h, 'Color','k','FontSize', 4, 'FontWeight', 'bold'); hold on
                % nodes_map(index_map({[hour, location, "start"]})) = size(nodes, 1) - 1;
                % nodes_map(index_map({[hour, location, "end"]})) = size(nodes, 1);

            end
        end
        
        % special_nodes = ["source", "entrance", "tier 1 ticket", "tier 2 ticket", "tier 3 ticket", "exit"]; 
        % for node_index = 1 : length(special_nodes)
        %     node = special_nodes(node_index);
        %     nodes = [nodes ; [-1, node_index]];
        %     h = text(hour, location_index + 0.5, sprintf('hour: %d, location: %s', hour, location));
        %         set(h, 'Color','k','FontSize', 4, 'FontWeight', 'bold'); hold on
        %     nodes_map(index_map({node})) = size(nodes, 1); 
        % end

        % Draw the exit 
        exit_position = [2, hours_open + 1]; 
        addNodeToGraph("exit", exit_position, "exit");
        % nodes = [nodes ; exit_position]; 
        % nodes_map(index_map({"exit"})) = size(nodes, 1); 
        % displayText(exit_position, "exit");

        % Draw the three tickets
        tickets = ["tier 1 ticket", "tier 2 ticket", "tier 3 ticket"];
        for ticket_index = 1 : length(tickets)
            ticket_position = [ticket_index, 0.5];
            addNodeToGraph(tickets(ticket_index), ticket_position, tickets(ticket_index));
            % nodes = [nodes ; ticket_position];
            % nodes_map(index_map({node})) = size(nodes, 1); 
            % displayText(ticket_position, tickets(ticket_index));
        end

        % Draw entrance and source
        % entrance_position = [2, 0]; 
        % addNodeToGraph("entrance", entrance_position, "entrance");
        % source_position = [2, -0.5]; 
        % addNodeToGraph("source", source_position, "source");

        headWidth = 8;
        headLength = 8;
        LineLength = 0.08;
        % Draw the edges
        for row = 1 : size(edge_matrix, 1) 
            for column = 1 : size(edge_matrix, 2)
                if edge_matrix(row, column) ~= 1
                    continue 
                end 
                if ~isKey(nodes_map, row) || ~isKey(nodes_map, column) 
                    continue
                end
                start_node = nodes(nodes_map(row), :); 
                end_node   = nodes(nodes_map(column), :);
                difference = end_node - start_node;
                

                quiver(start_node(1), start_node(2), difference(1), difference(2), 0); hold on
                % arrow = annotation('arrow', 'headStyle','cback1','HeadLength', headLength,'HeadWidth',headWidth);
                % set(arrow, 'position', [start_node, difference]); hold on 

                on_edge = start_node + 0.25 * difference;
                displayText(on_edge, sprintf('%d', solution(row, column)));
                % h = text(on_edge(1), on_edge(2), sprintf('%d', solution(row, column)));
                % set(h, 'Color','k','FontSize', 4, 'FontWeight', 'bold'); hold on
                % plot(edge(:, 1), edge(:, 2), 'b'); hold on
            end
        end 
        plot(nodes(:, 1), nodes(:, 2), 'bo'); hold on
    end

    getTotalTickets();
    displayGraph();
end
%%% 
%%% RUNNING
%%%


[solution, maximum_profit, has_solved, index_map, edge_matrix] = solveModel(HOURS_OPEN, TICKET_TIER_PRICES, ....
    SMALL_DRINK_PRICES, MEDIUM_DRINK_PRICES, LARGE_DRINK_PRICES, BAR_A_SITTING_CAPACITY, BAR_A_STANDING_CAPACITY, ... 
    MEAL_PRICES, BAR_B_CAPACITY, ... 
    DANCE_COST, TOTAL_PERSON_CAP);

if (has_solved)
    fprintf('Maximum Profit: $%.2f\n', maximum_profit);
    fprintf('Solution\n');
    displayResult(solution, index_map, edge_matrix, HOURS_OPEN)
end