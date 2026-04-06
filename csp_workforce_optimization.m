%% Annual Labor Cost Optimization and Workforce Allocation Model
%% Number of days

% Total days in month m (d_m) from Table II
d_m = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];

% Number of days of standard and promotional sales (n_{i,m}) from Table I
n_im = [22 19 22 21 22 21 22 22 21 22 21 22; % i=1: Standard Days
         6  6  6  6  6  6  6  6  6  6  6  6; % i=2: Payday Sale
         3  3  3  3  3  3  3  3  3  3  3  3]; %i=3: Double-Day Sale
%% Fixed demand parameters

% Synthesized demand data
D_i = [5000; 7500; 12500]; % Standard, Payday, Double-Day
S_m = [0.80, 0.80, 0.90, 0.90, 0.95, 1.00, 1.00, 1.05, 1.20, 1.25, 1.40, 1.50];
D_im = D_i * S_m; % Generates a 3x12 matrix of daily parcel volumes

% Display D_im matrix
fprintf('\n--- Synthesized parcel volume for each demand type in each month (D_im) ---\n');
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

jf = java.text.DecimalFormat('₱#,###.00');
ALC_p = char(jf.format(sum(C_p_m)));
fprintf("Total: %s\n", ALC_p) % Output sum to verify accuracy of array

C_p_13th = 18127.92;      
C_comm = 2.06;            
%% OCW monthly labor cost from Table VII

C_o_m = [24585.35, 21389.88, 23737.59, 25681.92, 24566.03, 23737.59, 23756.91, 23969.44, 22853.55, 23756.91, 23121.68, 26220.54]; 

jf = java.text.DecimalFormat('₱#,###.00');
ALC_o = char(jf.format(sum(C_o_m)));
fprintf("Total: %s\n", ALC_o) % Output sum to verify accuracy of array

C_o_13th_day = 64.40;     % distributed daily 13th-month agency billing (13th month pay equal to ₱20,158.24 ÷ 313 days = ₱64.40/day)
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
    
    prob.Constraints.(sprintf('SLA_Month_%d', m)) =
        (monthly_capacity_inhouse + monthly_capacity_ocw) >= monthly_demand;
end

% Constraints 2 & 3: Hub limit and manpower agency MOQ
for m = 1:12
    for i = 1:3
        % Hub capacity limit
        prob.Constraints.(sprintf('HubLimit_%d_%d', i, m)) =
            x1 + x2(i, m) <= M_max;
        
        % MOQ
        prob.Constraints.(sprintf('MOQ_Lower_%d_%d', i, m)) =
            x2(i, m) >= 10 * y(i, m);
            
        prob.Constraints.(sprintf('MOQ_Upper_%d_%d', i, m)) =
            x2(i, m) <= M_max * y(i, m);
    end
end

%% Solve

options = optimoptions('intlinprog', 'Display', 'final');
[sol, fval, exitflag, output] = solve(prob, 'Options', options);
%% Display Results

fprintf('\nOptimal Workforce Allocation\n');

% Creates a Java formatter to mark thousands place
jf = java.text.DecimalFormat('₱#,###.00');

% Format and display the total minimum cost using the Java formatter
formattedCost = char(jf.format(fval));
% Replacing the ₱ sign with PHP
formattedCost = strrep(formattedCost, '₱', ''); 

fprintf('Total annual cost: ₱%s\n', formattedCost);
fprintf('Permanent in-house riders (x1): %d\n', round(sol.x1));
fprintf('\nNumber of OCWs per demand type per month (x2_i_m):\n');

% Define headers for rows and columns
demand_types = {'Standard', 'Payday', 'Double-Day'};
months = {'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'};

% Convert the solution matrix into a readable table
x2_matrix = round(sol.x2);
x2_table = array2table(x2_matrix, 'RowNames', demand_types, 'VariableNames', months);

% Display the formatted table
disp(x2_table);

% Convert the solution matrix for 'y' into a readable table
fprintf('\nDecision to hire OCWs (y_i_m):\n');
y_matrix = round(sol.y);
y_table = array2table(y_matrix, 'RowNames', demand_types, 'VariableNames', months);

% Display the formatted table
disp(y_table);

%% Verify

fprintf('\n--- MONTHLY CAPACITY VERIFICATION ---\n');
monthly_req = zeros(1, 12);
monthly_cap = zeros(1, 12);

for m = 1:12
    monthly_req(m) = sum(n_im(:, m) .* D_im(:, m));
    monthly_cap(m) = (q_p * sol.x1 * sum(n_im(:, m))) + sum(q_o * n_im(:, m) .* sol.x2(:, m));
end

Verification = [monthly_req; monthly_cap; monthly_cap - monthly_req];
V_table = array2table(round(Verification), 'RowNames', {'Total_Demand', 'Total_Capacity', 'Surplus'}, 'VariableNames', months);
disp(V_table);