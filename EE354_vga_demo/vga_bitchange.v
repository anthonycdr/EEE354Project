`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Tron Light Cycles Game
// Separate trail grids to avoid synthesis issues
//////////////////////////////////////////////////////////////////////////////////
module vga_bitchange(
    input clk,
    input bright,
    input btnU,
    input btnD,
    input btnL,
    input btnR,
    input btnC,
    input [9:0] hCount, vCount,
    output reg [11:0] rgb,
    output reg [15:0] score
);
    
    // color
    parameter black  = 12'b0000_0000_0000;
    parameter white  = 12'b1111_1111_1111;
    parameter red    = 12'b1111_0000_0000;
    parameter green  = 12'b0000_1111_0000;
    parameter blue   = 12'b0000_0000_1111;
    parameter orange = 12'b1111_0110_0000;

    // VGA timing offsets (hCount 144-783 -> x 0-639, vCount 35-514 -> y 0-479)
    localparam h_off = 10'd144;
    localparam v_off = 10'd35;

    // make it from hCount to x_pos and vCount to y_pos, just easier overall bruh
    reg [9:0] x_pos;
    always @(*) begin
        if (hCount >= h_off && hCount < h_off + 10'd640) begin
            x_pos = hCount - h_off;
        end else begin
            x_pos = 10'd0;
        end
    end
    
    reg [9:0] y_pos;
    always @(*) begin
        if (vCount >= v_off && vCount < v_off + 10'd480) begin
            y_pos = vCount - v_off;
        end else begin
            y_pos = 10'd0;
        end
    end

    // grid values
    localparam cell_size = 10'd10;  
    localparam grid_w = 64;      
    localparam grid_h = 48;      
    localparam grid_size = grid_w * grid_h;  

    // directions
    localparam right = 2'b00;
    localparam left  = 2'b01;
    localparam up    = 2'b10;
    localparam down  = 2'b11;

    // player 1 blue
    reg [9:0] p1_x = 10'd200;
    reg [9:0] p1_y = 10'd240;
    reg [1:0] p1_dir = right;

    // player 2 orange
    reg [9:0] p2_x = 10'd400;
    reg [9:0] p2_y = 10'd240;

    // player heads
    reg p1_head, p2_head;
    always @(*) begin
        p1_head = (x_pos >= p1_x && x_pos < p1_x + cell_size &&
                   y_pos >= p1_y && y_pos < p1_y + cell_size);
        p2_head = (x_pos >= p2_x && x_pos < p2_x + cell_size &&
                   y_pos >= p2_y && y_pos < p2_y + cell_size);
    end

    // grid coordinates
    wire [5:0] p1_grid_x = p1_x / cell_size;
    wire [5:0] p1_grid_y = p1_y / cell_size;
    wire [5:0] p2_grid_x = p2_x / cell_size;
    wire [5:0] p2_grid_y = p2_y / cell_size;
    wire [5:0] px_grid_x = x_pos / cell_size;
    wire [5:0] px_grid_y = y_pos / cell_size;

    // SEPARATE trail grids for each player
    reg p1_trail_grid [0:grid_size-1];
    reg p2_trail_grid [0:grid_size-1];

    // bounds checking
    wire p1_in_bounds = (p1_grid_x < grid_w) && (p1_grid_y < grid_h);
    wire p2_in_bounds = (p2_grid_x < grid_w) && (p2_grid_y < grid_h);
    wire px_in_bounds = (px_grid_x < grid_w) && (px_grid_y < grid_h);

    // indices
    wire [11:0] p1_idx = p1_grid_y * grid_w + p1_grid_x;
    wire [11:0] p2_idx = p2_grid_y * grid_w + p2_grid_x;
    wire [11:0] px_idx = px_grid_y * grid_w + px_grid_x;

    // get trails at current pixel
    reg p1_trail_here, p2_trail_here;
    always @(*) begin
        if (px_in_bounds) begin
            p1_trail_here = p1_trail_grid[px_idx];
            p2_trail_here = p2_trail_grid[px_idx];
        end else begin
            p1_trail_here = 1'b0;
            p2_trail_here = 1'b0;
        end
    end

    // initialize grids
    integer i;
    initial begin
        for (i = 0; i < grid_size; i = i + 1) begin
            p1_trail_grid[i] = 1'b0;
            p2_trail_grid[i] = 1'b0;
        end
    end

    // movement timer
    reg [23:0] move_timer = 24'd0;
    reg game_over = 1'b0;
    wire reset = btnC;

    // p1 next position
    reg [9:0] p1_next_x, p1_next_y;
    always @(*) begin
        case (p1_dir)
            right: begin
                p1_next_x = (p1_x + cell_size >= 10'd640) ? 10'd0 : p1_x + cell_size;
                p1_next_y = p1_y;
            end
            left: begin
                p1_next_x = (p1_x == 10'd0) ? 10'd630 : p1_x - cell_size;
                p1_next_y = p1_y;
            end
            up: begin
                p1_next_x = p1_x;
                p1_next_y = (p1_y == 10'd0) ? 10'd470 : p1_y - cell_size;
            end
            down: begin
                p1_next_x = p1_x;
                p1_next_y = (p1_y + cell_size >= 10'd480) ? 10'd0 : p1_y + cell_size;
            end
            default: begin
                p1_next_x = p1_x;
                p1_next_y = p1_y;
            end
        endcase
    end

    // p2 just moves left
    wire [9:0] p2_next_x = (p2_x == 10'd0) ? 10'd630 : p2_x - cell_size;
    wire [9:0] p2_next_y = p2_y;

    // next grid coords
    wire [5:0] p1_next_grid_x = p1_next_x / cell_size;
    wire [5:0] p1_next_grid_y = p1_next_y / cell_size;
    wire p1_next_in_bounds = (p1_next_grid_x < grid_w) && (p1_next_grid_y < grid_h);
    wire [11:0] p1_next_idx = p1_next_grid_y * grid_w + p1_next_grid_x;

    wire [5:0] p2_next_grid_x = p2_next_x / cell_size;
    wire [5:0] p2_next_grid_y = p2_next_y / cell_size;
    wire p2_next_in_bounds = (p2_next_grid_x < grid_w) && (p2_next_grid_y < grid_h);
    wire [11:0] p2_next_idx = p2_next_grid_y * grid_w + p2_next_grid_x;

    // collision 
    wire p1_collision = p1_next_in_bounds && (p1_trail_grid[p1_next_idx] || p2_trail_grid[p1_next_idx]);
    wire p2_collision = p2_next_in_bounds && (p1_trail_grid[p2_next_idx] || p2_trail_grid[p2_next_idx]);

    // score
    always @(posedge clk) begin
        score <= game_over ? 16'd1 : 16'd0;
    end

    // p1 controls
    always @(posedge clk) begin
        if (reset)
            p1_dir <= right;
        else begin
            if (btnU) p1_dir <= up;
            else if (btnD) p1_dir <= down;
            else if (btnL) p1_dir <= left;
            else if (btnR) p1_dir <= right;
        end
    end

    // reset counter
    reg [11:0] reset_counter = 12'd0;
    reg resetting = 1'b0;

    // movement
    always @(posedge clk) begin
        if (reset && ~resetting) begin
            resetting <= 1'b1;
            reset_counter <= 12'd0;
            p1_x <= 10'd200;
            p1_y <= 10'd240;
            p2_x <= 10'd400;
            p2_y <= 10'd240;
            game_over <= 1'b0;
            move_timer <= 24'd0;
        end else if (resetting) begin
            p1_trail_grid[reset_counter] <= 1'b0;
            p2_trail_grid[reset_counter] <= 1'b0;
            reset_counter <= reset_counter + 12'd1;
            if (reset_counter == grid_size - 1)
                resetting <= 1'b0;
        end else begin
            move_timer <= move_timer + 24'd1;
            if (move_timer == 24'd0 && ~game_over) begin
                if (p1_collision || p2_collision) begin
                    game_over <= 1'b1;
                end else begin
                    if (p1_in_bounds)
                        p1_trail_grid[p1_idx] <= 1'b1;
                    if (p2_in_bounds)
                        p2_trail_grid[p2_idx] <= 1'b1;
                    p1_x <= p1_next_x;
                    p1_y <= p1_next_y;
                    p2_x <= p2_next_x;
                    p2_y <= p2_next_y;
                end
            end
        end
    end

    // display
    always @(*) begin
        if (~bright)
            rgb = black;
        else if (game_over)
            rgb = red;
        else if (p1_head)
            rgb = blue;
        else if (p2_head)
            rgb = orange;
        else if (p1_trail_here)
            rgb = blue;
        else if (p2_trail_here)
            rgb = orange;
        else
            rgb = black;
    end

endmodule