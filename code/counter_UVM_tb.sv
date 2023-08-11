import uvm_pkg::*;
`include "uvm_macros.svh"
`timescale 1ns/1ps


interface my_intf();
    logic [4:0] In;
    logic Load;
    logic Up;
    logic Down;
    logic [4:0] Counter;
    logic High;
    logic Low;
    logic Clk;
    logic Rst;
endinterface


class transaction extends uvm_sequence_item;

    rand logic [4:0] In;
    rand logic Load;
    rand logic Up;
    rand logic Down;
    logic [4:0] Counter;
    logic High;
    logic Low;
    logic Rst;

    function new(input string inst = "transaction");
        super.new(inst);
    endfunction

    `uvm_object_utils_begin(transaction)
    `uvm_field_int(In,UVM_DEC)
    `uvm_field_int(Load,UVM_DEC)
    `uvm_field_int(Up,UVM_DEC)
    `uvm_field_int(Down,UVM_DEC)
    `uvm_field_int(Counter,UVM_DEC)
    `uvm_field_int(High,UVM_DEC)
    `uvm_field_int(Low,UVM_DEC)
    `uvm_object_utils_end
endclass //transaction extends uvm_sequence_item


class generator extends uvm_sequence #(transaction);
    `uvm_object_utils(generator)

    transaction trans;

    function new(input string inst = "generator");
        super.new(inst);
    endfunction

    virtual task body();
    trans = transaction::type_id::create("trans");
    for (int i = 0 ; i<200 ; i++) begin
        start_item(trans);
        assert(trans.randomize()) else `uvm_fatal("geneartor", "Unable to randomize");
        finish_item(trans);
        
    end
    #10000;  //give time for the last transaction to complete
    endtask
endclass //generator extends uvm_sequence


class driver extends uvm_driver #(transaction);
    `uvm_component_utils(driver)

    transaction trans;
    virtual my_intf drv_intf;

    function new(input string inst ="driver",uvm_component comp);
        super.new(inst, comp);
    endfunction //new()

    virtual function void build_phase( uvm_phase phase);
        super.build_phase(phase);
        trans = transaction::type_id::create("trans");
        
        if(!uvm_config_db#(virtual my_intf)::get(this,"","my_intf", drv_intf))
            `uvm_fatal("driver", "Unable to access interface")
    endfunction

    virtual task run_phase(uvm_phase phase);
        forever begin
            seq_item_port.get_next_item(trans);
            //trans.print();
            drv_intf.In = trans.In;
            drv_intf.Load = trans.Load;
            drv_intf.Up = trans.Up;
            drv_intf.Down = trans.Down;
            seq_item_port.item_done();
            @(negedge drv_intf.Clk);
        end
    endtask
endclass //driver extends uvm_driver


class monitor extends uvm_monitor;
    `uvm_component_utils(monitor)

    transaction trans;
    virtual my_intf mon_intf;
    uvm_analysis_port #(transaction) mon_ap;

    function new(input string inst ="driver",uvm_component comp);
        super.new(inst, comp);
        mon_ap = new("mon_ap", this);
    endfunction //new()

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        trans = transaction::type_id::create("trans");
        
        if(!uvm_config_db#(virtual my_intf)::get(this,"","my_intf", mon_intf))
            `uvm_fatal("monitor", "Unable to access interface")
    endfunction

    virtual task run_phase(uvm_phase phase);
        forever begin
            @(posedge mon_intf.Clk);
            trans.In = mon_intf.In;
            trans.Load = mon_intf.Load;
            trans.Up = mon_intf.Up;
            trans.Down = mon_intf.Down;
            trans.Rst = mon_intf.Rst;
            @(negedge mon_intf.Clk);
            trans.Counter = mon_intf.Counter;
            trans.Low = mon_intf.Low;
            trans.High = mon_intf.High;
            //trans.print();
            mon_ap.write(trans);
        end
    endtask
endclass //monitor extends uvm_monitor


class agent extends uvm_agent;
    `uvm_component_utils(agent)

    uvm_analysis_port #(transaction) agt_ap;

    transaction trans;

    driver drv;
    monitor mon;
    uvm_sequencer #(transaction) seqr;

    function new(input string inst ="agent",uvm_component comp);
        super.new(inst, comp);
        agt_ap = new("agt_ap", this);
    endfunction //new()

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        drv = driver::type_id::create("drv1",this);
        mon = monitor::type_id::create("mon1",this);
        seqr = uvm_sequencer #(transaction)::type_id::create("seqr", this);
    endfunction
    
    virtual function void connect_phase(uvm_phase phase);
        drv.seq_item_port.connect(seqr.seq_item_export);
        mon.mon_ap.connect(agt_ap);
    endfunction
endclass


class scoreboard extends uvm_scoreboard;
    `uvm_component_utils(scoreboard)

    uvm_analysis_imp #(transaction, scoreboard) sco_ap;

    transaction trans[$];


    function new(input string inst ="scoreboard",uvm_component comp);
        super.new(inst, comp);
        sco_ap = new("sco_ap", this);
    endfunction //new()

    virtual function void write(transaction recv);
        trans.push_back(recv);
        //`uvm_info(get_type_name, "inside write function",UVM_NONE)
    endfunction

    virtual task run_phase(uvm_phase phase);
        transaction trans_item;
        int prev_counter = 0;
        int error, pass;

        forever begin
            wait(trans.size>0);
            if(trans.size>0)begin
                trans_item = trans.pop_front();

                if (!trans_item.Rst) begin
                    if (trans_item.Counter == 5'b0) begin
                        `uvm_info(get_type_name,"Result is as Expected",UVM_NONE)
                        pass++;
                    end
                    else begin
                        `uvm_info(get_type_name,"Wrong Result, counter should give zero",UVM_NONE)
                        error++;
                    end
                end
                else if(trans_item.Load == 1) begin
                    if(trans_item.In == trans_item.Counter) begin
                    `uvm_info(get_type_name,"Result is as Expected",UVM_NONE)
                    pass++;
                    end
                    else begin
                    `uvm_info(get_type_name,"Wrong Result, the loading is not working correctly",UVM_NONE)
                    error++;
                    end
                    prev_counter = trans_item.Counter;
                end
                else if(!trans_item.Load && (trans_item.Down) && !(trans_item.Up)) begin
                    if(trans_item.Counter == 5'b0 && (trans_item.Low)) begin
                        `uvm_info(get_type_name,"Result is as Expected",UVM_NONE)
                        pass++;
                    end
                    else if(trans_item.Counter == 5'b0 && !(trans_item.Low)) begin
                        `uvm_info(get_type_name,"Wrong Result, low signal is not high",UVM_NONE)
                        error++;
                    end
                    else if (trans_item.Counter == prev_counter -1) begin
                        `uvm_info(get_type_name,"Result is as Expected",UVM_NONE)
                        pass++;
                    end
                    else begin
                        `uvm_info(get_type_name,"Wrong Result, the counter is not counting down",UVM_NONE)
                        error++;
                    end
                    prev_counter = trans_item.Counter;
                end 
                else if(!trans_item.Load && (trans_item.Up) && !(trans_item.Down)) begin
                    if(trans_item.Counter == 5'b11111 && (trans_item.High) && !(trans_item.Down)) begin
                        `uvm_info(get_type_name,"Result is as Expected",UVM_NONE)
                        pass++;
                    end
                    else if(trans_item.Counter == 5'b11111 && (!trans_item.High) && !(trans_item.Down)) begin
                        `uvm_info(get_type_name,"Wrong Result, high signal is not high",UVM_NONE)
                        error++;
                    end
                    else if ((trans_item.Counter == prev_counter +1) && !(trans_item.Down)) begin
                        `uvm_info(get_type_name,"Result is as Expected",UVM_NONE)
                        pass++;
                    end
                    else begin
                        `uvm_info(get_type_name,"Wrong Result, the counter is not counting up",UVM_NONE)
                        error++;
                    end
                    prev_counter = trans_item.Counter;
                end
                else if(!trans_item.Load && !(trans_item.Up || trans_item.Down)) begin //neither counting up nor down
                    if (trans_item.Counter == prev_counter) begin
                        `uvm_info(get_type_name,"Result is as Expected",UVM_NONE)
                        pass++;
                    end
                    else begin
                        `uvm_info(get_type_name,"Wrong Result, counter should have maintained the previous count",UVM_NONE)
                        error++;
                    end
                end
                else if (!trans_item.Load && (trans_item.Up && trans_item.Down)) begin
                    if (trans_item.Counter == prev_counter) begin
                        `uvm_info(get_type_name,"Result is as Expected",UVM_NONE)
                        pass++;
                    end
                    else begin
                        `uvm_info(get_type_name,"Wrong Result, counter should have maintained the previous count",UVM_NONE)
                        error++;
                    end
                end
                
                else begin
                        `uvm_info(get_type_name,"Wrong Result, not working correctly",UVM_NONE)
                        error++;
                end
                `uvm_info(get_type_name,$sformatf("error: %0d, pass: %0d",error,pass),UVM_NONE)
            end
        end
    endtask
endclass //scoreboard extends uvm_scoreboard

class fun_coverage extends uvm_subscriber #(transaction);
    `uvm_component_utils(fun_coverage)

    transaction trans;

    uvm_analysis_imp #(transaction, fun_coverage) cov_ap;

    covergroup cg;
        cp1: coverpoint trans.In{
            bins b0 = {0};
            bins b1 = {1,2};
            bins b2 = {3};
            bins b3[] = {[4:5]};
        }
        cp2: coverpoint trans.Load;
        cp3: coverpoint trans.Up;
        cp4: coverpoint trans.Down;

    endgroup:cg

    function new(input string inst ="fun_coverage",uvm_component comp = null);
        super.new(inst, comp);
        cg = new();
        cov_ap = new("cov_ap", this);
    endfunction //new()

    function void write(transaction t);
        trans = t;
        cg.sample();
    endfunction

endclass //fun_coverage extends uvm_subscriber

class environment extends uvm_env;
    `uvm_component_utils(environment)

    agent agt;
    scoreboard sco;
    fun_coverage cov;

    function new(input string inst ="environment",uvm_component comp);
        super.new(inst, comp);
        //cov = new();
    endfunction //new()

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agt = agent::type_id::create("agt1", this);
        sco = scoreboard::type_id::create("sco1", this);
        cov = fun_coverage::type_id::create("cov1", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        agt.agt_ap.connect(sco.sco_ap);
        agt.agt_ap.connect(cov.analysis_export); //works right
        //agt.agt_ap.connect(cov.cov_ap); //also works right
    endfunction
endclass //environment extends uvm_env


class test1 extends uvm_test;
    `uvm_component_utils(test1)

    generator gen;
    environment env;

    function new(input string inst ="test1",uvm_component comp);
        super.new(inst, comp);
    endfunction //new()

    virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    gen = generator::type_id::create("gen1", this);
    env = environment::type_id::create("env1", this);
    endfunction

    virtual task run_phase(uvm_phase phase);
        phase.raise_objection(this);
        gen.start(env.agt.seqr);
        #6000;  //give time for the last assertion to complete
        `uvm_info("test1","before dropping objection",UVM_NONE)
        phase.drop_objection(this);
    endtask
endclass //test1 extends uvm_test


module counter_assertions (
    input   logic  [4:0]     In,
    input   logic            Load, Up, Down,
    input   logic            Clk,
    input   logic            Rst,
    input   logic   [4:0]     Counter,
    input   logic            High, Low
);

    property reset_property;
        @(posedge Clk) !Rst |-> (Counter == 5'b0);
    endproperty

    sequence up_sequence;
		!Load && Up && !Down && !High;
	endsequence

    property up_property;
        @(posedge Clk) disable iff(!Rst)
        up_sequence |=> (Counter == ($past(Counter, 1) + 1'b1));
    endproperty

    sequence down_sequence;
		!Load && Down && !Up && !Low;
	endsequence

    property down_property;
        @(posedge Clk) disable iff(!Rst)
        down_sequence |=> (Counter == ($past(Counter, 1) - 1'b1));
    endproperty

    property load_property;
		disable iff(!Rst)
		@(posedge Clk) Load |=> (Counter == $past(In,1));
	endproperty

    sequence stable_sequence;
		!Load &&Up && Down;
	endsequence

    property stable_property;
		disable iff(!Rst)
		@(posedge Clk) stable_sequence |=> ($stable(Counter));
	endproperty

    RST: assert property (reset_property) $display("RST, correct, time= %t",$realtime);else $error("RST, false, time= %t",$realtime);
    UP: assert property (up_property) $display("UP, correct, time= %t",$realtime);else $error("UP, false, time= %t",$realtime);
    DOWN: assert property (down_property) $display("DOWN, correct, time= %t",$realtime);else $error("DOWN, false, time= %t",$realtime);
    LOAD: assert property (load_property) $display("LOAD, correct, time= %t",$realtime);else $error("LOAD, false, time= %t",$realtime);
    STABLE: assert property (stable_property) $display("STABLE, correct, time= %t",$realtime);else $error("STABLE, false, time= %t",$realtime);

endmodule

module uvm_tb ();
//import "DPI-C" context function void ref_model();
    test1 t1;
    my_intf my_intf_instance();

    counter dut(
        .In(my_intf_instance.In),
        .Load(my_intf_instance.Load),
        .Up(my_intf_instance.Up),
        .Down(my_intf_instance.Down),
        .Clk(my_intf_instance.Clk),
        .Rst(my_intf_instance.Rst),
        .Counter(my_intf_instance.Counter),
        .High(my_intf_instance.High),
        .Low(my_intf_instance.Low)
    );

    bind uvm_tb.dut counter_assertions assert1(
        .In(my_intf_instance.In),
        .Load(my_intf_instance.Load),
        .Up(my_intf_instance.Up),
        .Down(my_intf_instance.Down),
        .Clk(my_intf_instance.Clk),
        .Rst(my_intf_instance.Rst),
        .Counter(my_intf_instance.Counter),
        .High(my_intf_instance.High),
        .Low(my_intf_instance.Low)
    );

    initial begin
        my_intf_instance.Clk = 1'b0;
        my_intf_instance.Rst = 1'b0;
        #10
        my_intf_instance.Rst = 1'b1;
    end

    always #5 my_intf_instance.Clk = ~my_intf_instance.Clk;

    initial begin
        $dumpvars;
        t1 = new("t1", null);
        uvm_config_db #(virtual my_intf)::set(null, "*", "my_intf", my_intf_instance);
        run_test();
        //#500;
    end
endmodule