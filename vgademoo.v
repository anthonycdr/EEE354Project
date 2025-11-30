`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Tron Light Cycles Game
// Two bikes leaving trails - collision detection to be added
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

    // grid values, so each pixel now is considered to be 10x10 block and theres 64 x 48 blocks
    localparam cell_size = 10'd10;  
    localparam grid_w = 64;      
    localparam grid_h = 48;      
    localparam grid_size = grid_w * grid_h;  

    // directions
    localparam right = 2'b00;
    localparam left  = 2'b01;
    localparam up    = 2'b10;
    localparam down  = 2'b11;

    // player 1 blue, starting points
    reg [9:0] p1_x = 10'd200;
    reg [9:0] p1_y = 10'd150;
    reg [1:0] p1_dir = right;

    // player 2 orange not moving rn
    localparam p2_x_init = 10'd400;
    localparam p2_y_init = 10'd300;

    // check if the pixel were in rn is part of each bikes head
    reg p1_head;
    always @(*) begin
        if (x_pos >= p1_x && x_pos < p1_x + cell_size) begin
            if (y_pos >= p1_y && y_pos < p1_y + cell_size) begin
                p1_head = 1;
            end else begin
                p1_head = 0;
            end
        end else begin
            p1_head = 0;
        end
    end
    
    reg p2_head;
    always @(*) begin
        if (x_pos >= p2_x_init && x_pos < p2_x_init + cell_size) begin
            if (y_pos >= p2_y_init && y_pos < p2_y_init + cell_size) begin
                p2_head = 1;
            end else begin
                p2_head = 0;
            end
        end else begin
            p2_head = 0;
        end
    end

    // convert the bike positions to the grid coords
    wire [5:0] p1_grid_x = p1_x / cell_size;  // 0-63
    wire [5:0] p1_grid_y = p1_y / cell_size;  // 0-47
    wire [5:0] px_grid_x = x_pos / cell_size;
    wire [5:0] px_grid_y = y_pos / cell_size;

    // trail memory: 2 bits per cell (00=empty, 01=P1 trail, 10=P2 trail)
    reg [1:0] trail_grid [0:grid_size-1];

    // bounds checking
    wire p1_in_bounds = (p1_grid_x < grid_w) && (p1_grid_y < grid_h);
    wire px_in_bounds = (px_grid_x < grid_w) && (px_grid_y < grid_h);

    // calculate memory indices
    wire [11:0] p1_idx = p1_grid_y * grid_w + p1_grid_x;
    wire [11:0] px_idx = px_grid_y * grid_w + px_grid_x;

    // get trail value at current pixel
    reg [1:0] px_trail;
    always @(*) begin
        if (px_in_bounds) begin
            px_trail = trail_grid[px_idx];
        end else begin
            px_trail = 2'b00;
        end
    end

    // make all cells empty
    integer i;
    initial begin
        for (i = 0; i < grid_size; i = i + 1)
            trail_grid[i] = 2'b00;
    end

    // movement timer (24-bit counter wraps every ~167ms at 100MHz)
    reg [23:0] move_timer = 24'd0;

    // game state
    reg game_over = 1'b0;
    
    // reset signal
    wire reset = btnC;

    // calculate next position based on current direction
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

    // convert next position to grid coords
    wire [5:0] p1_next_grid_x = p1_next_x / cell_size;
    wire [5:0] p1_next_grid_y = p1_next_y / cell_size;
    wire p1_next_in_bounds = (p1_next_grid_x < grid_w) && (p1_next_grid_y < grid_h);
    wire [11:0] p1_next_idx = p1_next_grid_y * grid_w + p1_next_grid_x;

    // collision detection, trail collision only rn i cant get the walls to work
    wire p1_collision = p1_next_in_bounds && (trail_grid[p1_next_idx] != 2'b00);

    // score output (shows 0 during play, 1 on game over)
    always @(posedge clk) begin
        score <= game_over ? 16'd1 : 16'd0;
    end

    // direction control for Player 1
    always @(posedge clk) begin
        if (reset) begin
            p1_dir <= right;
        end else begin
            if (btnU)
                p1_dir <= up;
            else if (btnD)
                p1_dir <= down;
            else if (btnL)
                p1_dir <= left;
            else if (btnR)
                p1_dir <= right;
        end
    end

    // reset counter for clearing trail grid
    reg [11:0] reset_counter = 12'd0;
    reg resetting = 1'b0;

    // movement and trail update
    always @(posedge clk) begin
        if (reset && ~resetting) begin
            // start reset process
            resetting <= 1'b1; // this a flag wow class stuff is useful, when 1 it starts resetting
            reset_counter <= 12'd0; 
            
            // reset player position
            p1_x <= 10'd200;
            p1_y <= 10'd150;
            game_over <= 1'b0;
            move_timer <= 24'd0;

        end else if (resetting) begin
            // clear trail grid one cell at a time
            trail_grid[reset_counter] <= 2'b00;
            reset_counter <= reset_counter + 12'd1;
            
            // done resetting when we've cleared all cells
            if (reset_counter == grid_size - 1)
                resetting <= 1'b0;
        end else begin
            move_timer <= move_timer + 24'd1;

            // update on counter overflow
            if (move_timer == 24'd0 && ~game_over) begin
                // check for collision before moving
                if (p1_collision) begin
                    game_over <= 1'b1;
                end else begin
                    // mark current position as P1 trail
                    if (p1_in_bounds)
                        trail_grid[p1_idx] <= 2'b01;

                    // move to next position
                    p1_x <= p1_next_x;
                    p1_y <= p1_next_y;
                end
            end
        end
    end

    // pixel color output
    always @(*) begin
        if (~bright) begin
            rgb = black;  // outside visible area
        end else if (game_over) begin
            rgb = red;    // flash red on game over
        end else if (p1_head) begin
            rgb = blue;   // p1 bike head
        end else if (p2_head) begin
            rgb = orange; // p2 bike head
        end else if (px_trail == 2'b01) begin
            rgb = blue;   // p1 trail
        end else if (px_trail == 2'b10) begin
            rgb = orange; // p2 trail
        end else begin
            rgb = black;  // Empty space
        end
    end

endmodule