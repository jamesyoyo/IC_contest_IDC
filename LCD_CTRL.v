module LCD_CTRL(clk, reset, cmd, cmd_valid, IROM_Q, IROM_rd, IROM_A, IRAM_valid, IRAM_D, IRAM_A, busy, done);
input clk;
input reset;
input [3:0] cmd;
input cmd_valid;
input [7:0] IROM_Q;
output reg IROM_rd;
output wire [5:0] IROM_A;
output reg IRAM_valid;
output reg [7:0] IRAM_D;
output wire [5:0] IRAM_A;
output reg busy;
output reg done;


parameter Write = 0, ShiftUp = 1, ShiftDown = 2, ShiftLeft = 3, ShfitRight = 4, Max = 5, Min = 6, Ave = 7, CCWRotation = 8, CWRotation = 9, MirrorX = 10, MirrorY = 11; 
parameter RData = 0, WData = 1, RCmd = 2, ExCmd = 3, Done = 4;
reg [2:0]state, nstate;
reg [7:0] temp [0:63];
reg [6:0]cnt;
reg cnt_re, cnt_en;
reg [5:0]pos[3:0];
reg [3:0]CmdTemp;
integer i;



always@(posedge clk or posedge reset)
begin
	if(reset) state <= RData;
	else state <= nstate;
end

always@(*)begin
	case(state)
		RData: nstate = (cnt[6])?RCmd:RData;
		WData: nstate = (cnt[6])?Done:WData;
		RCmd: nstate = (cmd_valid&&cmd==Write)?WData:(cmd_valid&&|cmd)?ExCmd:RCmd;
		ExCmd: nstate = RCmd;
		Done: nstate = Done;
	endcase
end

always@(*)
begin
	case(state)
		RCmd: begin
			done <= 1'b0;
			busy <= 1'b0;
			cnt_re <= 1'b0;
			cnt_en <= 1'b0;
			IROM_rd <= 1'b0;
			CmdTemp <= 4'b0;
		end
		RData: begin
			done <= 1'b0;
			busy <= 1'b1;
			cnt_re <= cnt[6];
			cnt_en <= 1'b1;
			IROM_rd <= 1'b1;
			CmdTemp <= 4'b0;
		end
		WData: begin
			done <= 1'b0;
			busy <= 1'b1;
			cnt_re <= cnt[6];
			cnt_en <= 1'b1;
			IROM_rd <= 1'b0;
			CmdTemp <= 4'b0;
		end
		ExCmd: begin
			done <= 1'b0;
			busy <= 1'b1;
			cnt_re <= 1'b1;
			cnt_en <= 1'b0;
			IROM_rd <= 1'b0;
			CmdTemp <= cmd;
		end
		Done: begin
			done <= 1'b1;
			busy <= 1'b0;
			cnt_re <= 1'b0;
			cnt_en <= 1'b0;
			IROM_rd <= 1'b0;
			CmdTemp <= 4'b0;
		end
	endcase
end

integer j;

always@(posedge clk or posedge reset)begin
	if(reset)begin
		pos[0] <= 27;
		pos[1] <= 28;
		pos[2] <= 35;
		pos[3] <= 36;
	end
	else if(state == ExCmd)begin
		case(CmdTemp)
			ShiftUp: for(j = 0; j < 4; j=j+1) pos[j] <= (pos[0] >= 8)?pos[j]-8:pos[j];
			ShiftDown: for(j = 0; j < 4; j=j+1) pos[j] <= (pos[2] <= 55)?pos[j]+8:pos[j];
			ShiftLeft: for(j = 0; j < 4; j=j+1) pos[j] <= ((pos[0] != 0) & (pos[0] != 8) &(pos[0] != 16) &(pos[0] != 32) &(pos[0] != 40) &(pos[0] != 48) &(pos[0] != 56))?pos[j]-1:pos[j];
			ShfitRight: for(j = 0; j < 4; j=j+1) pos[j] <= ((pos[1] != 7) & (pos[1] != 15) &(pos[1] != 23) &(pos[1] != 31) &(pos[1] != 39) &(pos[1] != 47) &(pos[1] != 55))?pos[j]+1:pos[j];
			default: for(j = 0; j < 4; j=j+1) pos[j] <= pos[j];
		endcase
	end
end

always@(posedge clk or posedge reset)begin
	if(reset ||cnt_re) cnt <= 0;
	else if(cnt_en) cnt <= cnt + 1;
end

assign 	IROM_A = cnt[5:0];
assign	IRAM_A = cnt[5:0];

wire [9:0]average;
assign average = (temp[pos[0]]+temp[pos[1]]+temp[pos[2]]+temp[pos[3]])>>2;
integer k;
always@(posedge clk or posedge reset)
begin
	if(reset) for(i = 0; i < 64 ;i = i +1) temp[i] <= 0;
	else if(state == RData) temp[cnt[5:0]] <= IROM_Q;
	else if(state ==ExCmd)begin
		case(CmdTemp)
			Max: begin
				for(k = 0; k < 4; k = k+1) temp[pos[k]] <= CMP(temp[pos[0]],temp[pos[1]],temp[pos[2]],temp[pos[3]],1);
			end
			Min: for(k = 0; k < 4; k = k+1) temp[pos[k]] <= CMP(temp[pos[0]],temp[pos[1]],temp[pos[2]],temp[pos[3]],0);
			Ave: for(k = 0; k < 4; k = k+1) temp[pos[k]] <= average;
			CCWRotation:begin
				temp[pos[0]] <= temp[pos[1]];
				temp[pos[1]] <= temp[pos[3]];
				temp[pos[2]] <= temp[pos[0]];
				temp[pos[3]] <= temp[pos[2]];
			end

			CWRotation:begin
				temp[pos[0]] <= temp[pos[2]];
				temp[pos[1]] <= temp[pos[0]];
				temp[pos[2]] <= temp[pos[3]];
				temp[pos[3]] <= temp[pos[1]];
			end
			MirrorX:begin
				temp[pos[0]] <= temp[pos[2]];
				temp[pos[1]] <= temp[pos[3]];
				temp[pos[2]] <= temp[pos[0]];
				temp[pos[3]] <= temp[pos[1]];
			end
			MirrorY:begin
				temp[pos[0]] <= temp[pos[1]];
				temp[pos[1]] <= temp[pos[0]];
				temp[pos[2]] <= temp[pos[3]];
				temp[pos[3]] <= temp[pos[2]];
			end
		endcase
	end
end

function [7:0]CMP; 
	input [7:0]v1,v2,v3,v4;
	input ctrl;
	reg [7:0]c1,c2;
	if(ctrl)begin
		c1 = (v1>v2)?v1:v2;
		c2 = (v3>v4)?v3:v4;
		CMP = (c1>c2)?c1:c2;
	end
	else begin
		c1 = (v1<v2)?v1:v2;
		c2 = (v3<v4)?v3:v4;
		CMP = (c1<c2)?c1:c2;
	end
endfunction

always@(*)
begin
	case(state)
		WData: begin
			IRAM_valid <= 1'b1;
			IRAM_D <= temp[cnt[5:0]];
		end
		default: begin
			IRAM_valid <= 1'b0;
			IRAM_D <= 8'b0;
		end
	endcase
end

endmodule



