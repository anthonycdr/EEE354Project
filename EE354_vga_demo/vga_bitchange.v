`timescale 1ns / 1ps

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

    // VGA timing offsets (hCount 144-783 to 0-639, vCount 35-514 to y 0-479)
    localparam h_off = 10'd144;
    localparam v_off = 10'd35;

    // make it from hCount to x_pos and vCount to y_pos, just easier overall bruh
    reg [9:0] x_pos;
    always @(*) begin
        if (hCount >= h_off) begin
            if (hCount < h_off+ 10'd640) begin
                x_pos = hCount-h_off;
            end else begin
                x_pos = 10'd0;
            end
        end else begin
            x_pos = 10'd0;
        end
    end
    
    reg [9:0] y_pos;
    always @(*) begin
        if (vCount >= v_off) begin
            if (vCount < v_off +10'd480) begin
                y_pos = vCount - v_off;
            end else begin
                y_pos = 10'd0;
            end
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
    reg p1_head;
    reg p2_head;
    always @(*) begin
        if (x_pos >= p1_x) begin
            if (x_pos < p1_x + cell_size) begin
                if (y_pos >= p1_y) begin
                    if (y_pos < p1_y + cell_size) begin
                        p1_head = 1;
                    end else begin
                        p1_head = 0;
                    end
                end else begin
                    p1_head = 0;
                end
            end else begin
                p1_head = 0;
            end
        end else begin
            p1_head = 0;
        end
        
        if (x_pos >= p2_x) begin
            if (x_pos < p2_x+ cell_size) begin
                if (y_pos >= p2_y) begin
                    if (y_pos < p2_y+ cell_size) begin
                        p2_head = 1;
                    end else begin
                        p2_head = 0;
                    end
                end else begin
                    p2_head = 0;
                end
            end else begin
                p2_head = 0;
            end
        end else begin
            p2_head = 0;
        end
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
    reg p1_in_bounds;
    always @(*) begin
        if (p1_grid_x < grid_w) begin
            if (p1_grid_y < grid_h) begin
                p1_in_bounds = 1;
            end else begin
                p1_in_bounds = 0;
            end
        end else begin
            p1_in_bounds = 0;
        end
    end
    
    reg p2_in_bounds;
    always @(*) begin
        if (p2_grid_x < grid_w) begin
            if (p2_grid_y < grid_h) begin
                p2_in_bounds = 1;
            end else begin
                p2_in_bounds = 0;
            end
        end else begin
            p2_in_bounds = 0;
        end
    end
    
    reg px_in_bounds;
    always @(*) begin
        if (px_grid_x < grid_w) begin
            if (px_grid_y < grid_h) begin
                px_in_bounds = 1;
            end else begin
                px_in_bounds = 0;
            end
        end else begin
            px_in_bounds = 0;
        end
    end

    // indices into trail grids, basically getting which cell each player is on later on 
    wire [11:0] p1_idx = p1_grid_y * grid_w + p1_grid_x;
    wire [11:0] p2_idx = p2_grid_y * grid_w + p2_grid_x;
    wire [11:0] px_idx = px_grid_y * grid_w + px_grid_x;

    // get trails at current pixel
    reg p1_trail_here;
    reg p2_trail_here;
    always @(*) begin
        if (px_in_bounds == 1) begin
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
        for (i = 0; i < grid_size; i=i+1) begin
            p1_trail_grid[i] = 1'b0;
            p2_trail_grid[i] = 1'b0;
        end
    end

    // movement timer
    reg [23:0] move_timer = 24'd0;
    reg game_over = 1'b0;
    wire reset = btnC;

    // p1 next position, basically wrap around, this is where we needa chnage later for wall collisions i think and just +1 cell for right n up  -1 cell for left n down
    reg [9:0] p1_next_x;
    reg [9:0] p1_next_y;
    always @(*) begin
        if (p1_dir == right) begin
            if (p1_x + cell_size >= 10'd640) begin
                p1_next_x = 10'd0;
            end else begin
                p1_next_x = p1_x + cell_size;
            end
            p1_next_y = p1_y;
        end else if (p1_dir == left) begin
            if (p1_x == 10'd0) begin
                p1_next_x = 10'd630;
            end else begin
                p1_next_x = p1_x - cell_size;
            end
            p1_next_y = p1_y;
        end else if (p1_dir == up) begin
            p1_next_x = p1_x;
            if (p1_y == 10'd0) begin
                p1_next_y = 10'd470;
            end else begin
                p1_next_y = p1_y - cell_size;
            end
        end else if (p1_dir == down) begin
            p1_next_x = p1_x;
            if (p1_y + cell_size >= 10'd480) begin
                p1_next_y = 10'd0;
            end else begin
                p1_next_y = p1_y + cell_size;
            end
        end else begin
            p1_next_x = p1_x;
            p1_next_y = p1_y;
        end
    end

    // p2 just moves left
    reg [9:0] p2_next_x;
    reg [9:0] p2_next_y;
    always @(*) begin
        if (p2_x == 10'd0) begin
            p2_next_x = 10'd630;
        end else begin
            p2_next_x = p2_x - cell_size;
        end
        p2_next_y = p2_y;
    end

    // next grid coords
    wire [5:0] p1_next_grid_x = p1_next_x / cell_size;
    wire [5:0] p1_next_grid_y = p1_next_y / cell_size;
    
    reg p1_next_in_bounds;
    always @(*) begin
        if (p1_next_grid_x < grid_w) begin
            if (p1_next_grid_y < grid_h) begin
                p1_next_in_bounds = 1;
            end else begin
                p1_next_in_bounds = 0;
            end
        end else begin
            p1_next_in_bounds = 0;
        end
    end
    
    wire [11:0] p1_next_idx = p1_next_grid_y * grid_w + p1_next_grid_x;

    wire [5:0] p2_next_grid_x = p2_next_x / cell_size;
    wire [5:0] p2_next_grid_y = p2_next_y / cell_size;
    
    reg p2_next_in_bounds;
    always @(*) begin
        if (p2_next_grid_x < grid_w) begin
            if (p2_next_grid_y < grid_h) begin
                p2_next_in_bounds = 1;
            end 
			else begin
                p2_next_in_bounds = 0;
            end
        end 
		else begin
            p2_next_in_bounds = 0;
        end
    end
    
    wire [11:0] p2_next_idx = p2_next_grid_y* grid_w +p2_next_grid_x;

    // collision 
    reg p1_collision;
    always @(*) begin
        if (p1_next_in_bounds == 1) begin
            if (p1_trail_grid[p1_next_idx] == 1) begin
                p1_collision = 1;
            end else if (p2_trail_grid[p1_next_idx] == 1) begin
                p1_collision = 1;
            end else begin
                p1_collision = 0;
            end
        end else begin
            p1_collision = 0;
        end
    end
    
    reg p2_collision;
    always @(*) begin
        if (p2_next_in_bounds == 1) begin
            if (p1_trail_grid[p2_next_idx] == 1) begin
                p2_collision = 1;
            end else if (p2_trail_grid[p2_next_idx] == 1) begin
                p2_collision = 1;
            end else begin
                p2_collision = 0;
            end
        end else begin
            p2_collision = 0;
        end
    end

    // score
    always @(posedge clk) begin
        if (game_over == 1) begin
            score <= 16'd1;
        end else begin
            score <= 16'd0;
        end
    end

    // p1 controls
    always @(posedge clk) begin
        if (reset == 1) begin
            p1_dir <= right;
        end else begin
            if (btnU == 1) begin
                p1_dir <= up;
            end else if (btnD == 1) begin
                p1_dir <= down;
            end else if (btnL == 1) begin
                p1_dir <= left;
            end else if (btnR == 1) begin
                p1_dir <= right;
            end
        end
    end

    // reset counter
    reg [11:0] reset_counter = 12'd0;
    reg resetting = 1'b0;

    // movement timer and reset logic
    always @(posedge clk) 
	begin
        if (reset == 1) 
		begin
            if (resetting == 0) 
			begin
                resetting <= 1'b1;
                reset_counter <= 12'd0;
                p1_x <= 10'd200;
                p1_y <= 10'd240;
                p2_x <= 10'd400;
                p2_y <= 10'd240;
                game_over <= 1'b0;
                move_timer <= 24'd0;
            end
        end 
		
		else if (resetting == 1) 
		begin
            p1_trail_grid[reset_counter] <= 1'b0;
            p2_trail_grid[reset_counter] <= 1'b0;
            reset_counter <= reset_counter+ 12'd1;
            if (reset_counter == grid_size -1) 
			begin
                resetting <= 1'b0;
            end
        end 
		
		else 
		begin
            move_timer <= move_timer +24'd1;
            if (move_timer == 24'd0) begin
                if (game_over == 0) begin
                    if (p1_collision == 1) begin
                        game_over <= 1'b1;
                    end else if (p2_collision == 1) begin
                        game_over <= 1'b1;
                    end else begin
                        if (p1_in_bounds == 1) begin
                            p1_trail_grid[p1_idx] <= 1'b1;
                        end
                        if (p2_in_bounds == 1) begin
                            p2_trail_grid[p2_idx] <= 1'b1;
                        end
                        p1_x <= p1_next_x;
                        p1_y <= p1_next_y;
                        p2_x <= p2_next_x;
                        p2_y <= p2_next_y;
                    end
                end
            end
        end
    end

    // display
    always @(*) 
	begin
        if (bright == 0) begin
            rgb = black;
        end else if (game_over == 1) begin
            rgb = red;
        end else if (p1_head == 1) begin
            rgb = blue;
        end else if (p2_head == 1) begin
            rgb = orange;
        end else if (p1_trail_here == 1) begin
            rgb = blue;
        end else if (p2_trail_here == 1) begin
            rgb = orange;
        end else begin
            rgb = black;
        end
    end

endmodule
