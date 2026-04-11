%% Annual Labor Cost Optimization and Workforce Allocation Model
%% Number of days

% Total days in month m (d_m) from Table II
d_m = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];

% Number of days of standard and promotional sales (n_{i,m}) from Table I
n_im = [22 19 22 21 22 21 22 22 21 22 21 22; % i=1: Standard Days
         6  6  6  6  6  6  6  6  6  6  6  6; % i=2: Payday Sale
         3  3  3  3  3  3  3  3  3  3  3  3]; %i=3: Double-Day Sale
%% Fixed demand parameters% Synthesized demand data

D_i = [5000; 7500; 12500]; % Standard, Payday, Double-Day
S_m = [0.80, 0.80, 0.90, 0.90, 0.95, 1.00, 1.00, 1.05, 1.20, 1.25, 1.40, 1.50];
D_im = D_i * S_m; % Generates a 3x12 matrix of daily parcel volumes

% Display D_im matrix
fprintf('\nSynthesized parcel volume for each demand type in each month (D_im)\n');
demand_types = {'Standard', 'Payday', 'Double-Day'};
months = {'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'};
Dim_table = array2table(round(D_im), 'RowNames', demand_types, 'VariableNames', months);
disp(Dim_table);
%% Fixed operational capacities

% Synthesized operational capacities
q_p = 80;   % In-house rider capacity
q_o = 60;   % OCW rider capacity
M_max = 150; % Maximum physical hub limit
%% In-house monthly labor cost from Table VI

C_p_m = [22109.13, 19235.50, 21346.75, 23095.25, 22091.75, 21346.75, 21364.13 21555.25 20551.75 21364.13, 20792.88, 23579.63];

jf = java.text.DecimalFormat('₱ #,###.00');
ALC_p = char(jf.format(sum(C_p_m)));
fprintf("Annual labor cost of a single in-house rider: %s\n", ALC_p) % Output sum to verify accuracy of array

C_p_13th = 18127.92;      
C_comm = 2.06;            
%% OCW monthly labor cost from Table VII

C_o_m = [24585.35, 21389.88, 23737.59, 25681.92, 24566.03, 23737.59, 23756.91, 23969.44, 22853.55, 23756.91, 23121.68, 26220.54]; 

jf = java.text.DecimalFormat('₱ #,###.00');
ALC_o = char(jf.format(sum(C_o_m)));
fprintf("Annual agency billing of a single OCW rider: %s\n", ALC_o) % Output sum to verify accuracy of array

C_o_13th_day = 64.40;     % distributed daily 13th-month agency billing (13th month pay equal to ₱ 20,158.24 ÷ 313 days = ₱ 64.40/day)
%% Define decision variables

% x1: In-house permanent riders (1 value for the whole year)
x1 = optimvar('x1', 1, 'Type', 'integer', 'LowerBound', 0);

% x2: OCWs hired per demand type i, per month m (3x12 matrix)
x2 = optimvar('x2', 3, 12, 'Type', 'integer', 'LowerBound', 0);

% y: Decision to hire OCWs (3x12 matrix)
y = optimvar('y', 3, 12, 'Type', 'integer', 'LowerBound', 0, 'UpperBound', 1);
%% Define objective function

prob = optimproblem('ObjectiveSense', 'minimize');

% Objective function consists of three distinct groups of terms:
% 1st and 2nd: fixed in-house wage cost, 
% 3rd and 4th: variable OCW wage cost,
% 5th: and commission cost

% Fixed in-house wage cost
cost_inhouse = x1 * (sum(C_p_m) + C_p_13th);

% Variable OCW wage cost
daily_rate_im = repmat(C_o_m ./ d_m, 3, 1);
cost_ocw_billing = sum(sum(daily_rate_im .* n_im .* x2));
cost_ocw_13th = sum(sum(C_o_13th_day .* n_im .* x2));

cost_ocw = cost_ocw_billing + cost_ocw_13th;

% Commission cost
cost_comm = C_comm * sum(sum(n_im .* D_im));

% Total Z_annual
prob.Objective = cost_inhouse + cost_ocw + cost_comm;

%% Define constraints

% Constraint 1: SLA Fulfillment (Monthly Clearance)
for m = 1:12
    monthly_capacity_inhouse = q_p * x1 * sum(n_im(:, m));
    monthly_capacity_ocw = sum(q_o * n_im(:, m) .* x2(:, m));
    monthly_demand = sum(n_im(:, m) .* D_im(:, m));
    
    prob.Constraints.(sprintf('SLA_Month_%d', m)) = (monthly_capacity_inhouse + monthly_capacity_ocw) >= monthly_demand;
end

% Constraints 2 & 3: Hub limit and manpower agency MOQ
for m = 1:12
    for i = 1:3
        % Hub capacity limit
        prob.Constraints.(sprintf('HubLimit_%d_%d', i, m)) = x1 + x2(i, m) <= M_max;
        
        % MOQ
        prob.Constraints.(sprintf('MOQ_Lower_%d_%d', i, m)) = x2(i, m) >= 10 * y(i, m);
            
        prob.Constraints.(sprintf('MOQ_Upper_%d_%d', i, m)) = x2(i, m) <= M_max * y(i, m);
    end
end
%% Solve

options = optimoptions('intlinprog', 'Display', 'final');
[sol, fval, exitflag, output] = solve(prob, 'Options', options);
%% Display Results

fprintf('\nOptimal Workforce Allocation\n');

% Format the total OPEX
formattedCost = char(jf.format(fval));
formattedCost = strrep(formattedCost, '₱ ', ''); 

total_inhouse_wage = sol.x1 * (sum(C_p_m) + C_p_13th);

daily_rate_im = repmat(C_o_m ./ d_m, 3, 1);
total_ocw_wage = sum(sum((daily_rate_im + C_o_13th_day) .* n_im .* sol.x2));

total_comm = C_comm * sum(sum(n_im .* D_im));

jf = java.text.DecimalFormat('#,###.00');

fprintf('Permanent In-house Riders (x1): %d\n', round(sol.x1));
fprintf('----------------------------------------------------------\n');
fprintf('ANNUAL COST BREAKDOWN:\n');
fprintf('Fixed In-house Wages:      ₱ %s\n', char(jf.format(total_inhouse_wage)));
fprintf('Variable OCW Wages:        ₱ %s\n', char(jf.format(total_ocw_wage)));
fprintf('Delivery Commissions:      ₱ %s\n', char(jf.format(total_comm)));
fprintf('----------------------------------------------------------\n');
fprintf('TOTAL ANNUAL OPEX:         ₱ %s\n', char(jf.format(fval)));

fprintf('\nOptimal number of OCWs to deploy per period (x2_i_m):\n');
x2_matrix = round(sol.x2);
x2_table = array2table(x2_matrix, 'RowNames', demand_types, 'VariableNames', months);
disp(x2_table);

writetable(x2_table, 'ocws_to_deploy_per_period.csv'); 

fprintf('\nDecision to hire OCWs triggered (y_i_m):\n');
y_matrix = round(sol.y);
y_table = array2table(y_matrix, 'RowNames', demand_types, 'VariableNames', months);
disp(y_table);

writetable(y_table, 'ocws_hiring_decision.csv'); 

fprintf('\nMonthly Capacity\n');
monthly_req = zeros(1, 12);
monthly_cap = zeros(1, 12);

for m = 1:12
    % Reverted verification loop to match the monthly clearance logic
    monthly_req(m) = sum(n_im(:, m) .* D_im(:, m));
    monthly_cap(m) = (q_p * sol.x1 * sum(n_im(:, m))) + sum(q_o * n_im(:, m) .* sol.x2(:, m));
end

Verification = [monthly_req; monthly_cap; monthly_cap - monthly_req];
V_table = array2table(round(Verification), 'RowNames', {'Total_Demand', 'Total_Capacity', 'Surplus'}, 'VariableNames', months);
disp(V_table);

writetable(V_table, 'demand_vs_capacity.csv'); 
%% Sensitivity Analysis

fprintf('Sensitivity Analysis\n');

% Set up the multipliers (80% to 150% of original cost)
ocw_multipliers = 0.80 : 0.10 : 1.50; 
num_scenarios = length(ocw_multipliers);

res_x1 = zeros(1, num_scenarios);
res_total_cost = zeros(1, num_scenarios);

options.Display = 'none'; 

fprintf('\nMultiplier | OCW Rate Shift | Permanent Riders (x1) | Total OPEX\n');
fprintf('------------------------------------------------------------------\n');

for s = 1:num_scenarios
    mult = ocw_multipliers(s);
    
    % Scale the OCW daily rate
    adj_daily_rate = (repmat(C_o_m ./ d_m, 3, 1) + C_o_13th_day) * mult;
    
    % Re-build the variable cost expression to account for OCW daily rate
    current_ocw_cost = sum(sum(adj_daily_rate .* n_im .* x2));
    
    % Update the objective function to account for new daily rate, inhouse
    % and commission costs remain the same as only the agency billing is
    % changed
    prob.Objective = cost_inhouse + current_ocw_cost + cost_comm;
    
    % Solve the objective function
    [sol_sens, fval_sens] = solve(prob, 'Options', options);
    
    % Store and display the results
    res_x1(s) = round(sol_sens.x1);
    res_total_cost(s) = fval_sens; 
    
    fprintf('   %.2fx   |      %+3.0f%%      |          %d           | ₱ %s |\n', ...
            mult, (mult-1)*100, res_x1(s), char(jf.format(res_total_cost(s))));
end

% Plot the results
figure;
subplot(2,1,1);
plot(ocw_multipliers * 100, res_x1, '-o', 'LineWidth', 2, 'MarkerSize', 6);
title('Sensitivity of Permanent Riders (x_1) to OCW Rate');
xlabel('OCW Billing Rate as Percentage of Base Cost (%)');
ylabel('Number of Permanent Riders');
grid on;

subplot(2,1,2);
plot(ocw_multipliers * 100, res_total_cost / 1e6, '-s', 'LineWidth', 2, 'Color', '#D95319');
title('Impact of OCW Rate Changes on Total Annual OPEX');
xlabel('OCW Billing Rate as Percentage of Base Cost (%)');
ylabel('Total OPEX (Millions PHP)');
grid on;