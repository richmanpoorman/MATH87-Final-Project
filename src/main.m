
%%%
%%% MODEL CONSTANTS
%%%

%% HOURS
HOURS_OPEN = 12; 
TICKET_TIER_PRICES = [30, 20, 10]; % Prices to get in every 4 hrs

%% BAR A
SMALL_DRINK_PRICES = 5 * ones(HOURS_OPEN);
MEDIUM_DRINK_PRICES = 6 * ones(HOURS_OPEN); 
LARGE_DRINK_PRICES = 7 * ones(HOURS_OPEN); 

BAR_A_SITTING_CAPACITY = 10; 
BAR_A_STANDING_CAPACITY = 2 * BAR_A_SITTING_CAPACITY; 

%% BAR B 
MEAL_PRICES = 10 * ones(HOURS_OPEN); 

BAR_B_CAPACITY = 25; 

%% DANCE FLOOR
DANCE_COST = 5 * ones(HOURS_OPEN);

%%%
%%% BUILD MODEL 
%%%

% Creates a triple nested map, which has 
% indexMap := [hour(int)]["bar_a" | "bar_b" | "dance_floor"]["start" | "end"] = index | 
%             ["tier_1_ticket" | "tier_2_ticket" | "tier_3_ticket" | "exit"] = index
function [index_map, num_indexes] = createMap(hours_open)
    index_counter = 1; 
    location_options = ["bar_a", "bar_b", "dance_floor"];
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

    other_nodes = ["tier_1_ticket", "tier_2_ticket", "tier_3_ticket", "exit"];

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
               dance_costs)
    
    location_options = ["bar_a", "bar_b", "dance_floor"];
    at_hour_options = ["start", "end"]; 
    other_nodes = ["tier_1_ticket", "tier_2_ticket", "tier_3_ticket", "exit"];
    
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

            if location == "bar_a"
                addEdge(start_index, end_index, bar_a_sitting_capacity, medium_drink_prices(hour)); 
            elseif location == "bar_b"
                addEdge(start_index, end_index, bar_b_capacity, meal_prices(hour)); 
            elseif location == "dance_floor"
                addEdge(start_index, end_index, inf, -dance_costs(hour)); 
            end
        end
    end

    % Entering and exiting bar A
    for hour = 1 : hours_open
        start_index = index_map({[hour, "bar_a", "start"]}); 
        
        % From Staying in the bar
        if hour ~= 1
            previous_bar_a = index_map({[hour - 1, "bar_a", "end"]}); 
            addEdge(previous_bar_a, start_index, inf, 0); 
        end
        
        % From entering from the dance floor
        if hour ~= 1
            previous_dance_floor = index_map({[hour - 1, "dance_floor", "end"]});  
            addEdge(previous_dance_floor, start_index, inf, 0); 
        end 
        
        % From entering via the ticket 
        ticket_range = floor(hours_open ./ size(ticket_tier_prices, 1));
        ticket_tier  = floor((hour - 1) ./ ticket_range) + 1; 
        tier_index   = index_map({other_nodes(ticket_tier)});
        addEdge(tier_index, start_index, inf, ticket_tier_prices(ticket_tier) + large_drink_prices(hour));

        % Grabbing a drink and leaving immediately 
        current_dance_floor = index_map({[hour, "dance_floor", "start"]});
        addEdge(start_index, current_dance_floor, bar_a_standing_capacity, small_drink_prices(hour));

        % Leaving the bar to go do the dance floor
        end_index   = index_map({[hour, "bar_a", "end"]}); 
        if hour ~= hours_open
            next_dance_floor = index_map({[hour + 1, "dance_floor", "start"]});
            addEdge(end_index, next_dance_floor, inf, small_drink_prices(hour));
        else 
            % at the end of the hour, exit the club if at the bar
            exit_index = index_map({"exit"});
            addEdge(end_index, exit_index, inf, 0);
        end 
        
    end

    % Entering and exiting bar b
    for hour = 1 : hours_open
        start_index = index_map({[hour, "bar_b", "start"]}); 
        
        % From entering from the dance floor
        if hour ~= 1
            previous_dance_floor = index_map({[hour - 1, "dance_floor", "end"]});  
            addEdge(previous_dance_floor, start_index, inf, 0); 
        end 

        % From entering via the ticket 
        ticket_range = floor(hours_open ./ size(ticket_tier_prices, 1));
        ticket_tier  = floor((hour - 1) ./ ticket_range) + 1; 
        tier_index   = index_map({other_nodes(ticket_tier)});
        addEdge(tier_index, start_index, inf, ticket_tier_prices(ticket_tier));

        end_index = index_map({[hour, "bar_b", "end"]}); 
        if hour ~= hours_open
            next_dance_floor = index_map({[hour + 1, "dance_floor", "start"]});
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
        start_index = index_map({[hour, "dance_floor", "start"]}); 
        ticket_range = floor(hours_open ./ size(ticket_tier_prices, 1));
        ticket_tier  = floor((hour - 1) ./ ticket_range) + 1; 
        tier_index   = index_map({other_nodes(ticket_tier)});
        addEdge(tier_index, start_index, inf, ticket_tier_prices(ticket_tier));

        end_index = index_map({[hour, "dance_floor", "end"]}); 
        if hour ~= hours_open
            next_dance_floor = index_map({[hour + 1, "dance_floor", "start"]});
            addEdge(end_index, next_dance_floor, inf, 0);
        else
            % at the end of the hour, exit the club if at the bar
            exit_index = index_map({"exit"});
            addEdge(end_index, exit_index, inf, 0);
        end
    end

end


%%% 
%%% RUNNING
%%%

[index_map, edge_matrix, upper_bound_matrix, lower_bound_matrix, costs_matrix] = ...
    buildGraph(HOURS_OPEN, TICKET_TIER_PRICES, ....
               SMALL_DRINK_PRICES, MEDIUM_DRINK_PRICES, LARGE_DRINK_PRICES, BAR_A_SITTING_CAPACITY, BAR_A_STANDING_CAPACITY, ... 
               MEAL_PRICES, BAR_B_CAPACITY, ... 
               DANCE_COST);

solution = network_flow(edge_matrix, upper_bound_matrix, lower_bound_matrix, costs_matrix)