/***********************************************************************
 * A SystemVerilog testbench for an instruction register.
 * The course labs will convert this to an object-oriented testbench
 * with constrained random test generation, functional coverage, and
 * a scoreboard for self-verification.
 *
 * SystemVerilog Training Workshop.
 * Copyright 2006, 2013 by Sutherland HDL, Inc.
 * Tualatin, Oregon, USA.  All rights reserved.
 * www.sutherland-hdl.com
 **********************************************************************/

module instr_register_test (tb_ifc io);  // interface port

  timeunit 1ns/1ns;

  // user-defined types are defined in instr_register_pkg.sv
  import instr_register_pkg::*;

  int seed = 555;

  class transaction;
    rand opcode_t      opcode;
    rand operand_t     operand_a,operand_b;
    address_t     write_pointer;

    constraint operand_a_const{
      operand_a<=15;
      operand_a>=-15;
    }

    constraint operand_b_const{
      operand_b<=15;
      operand_b>=0;
    }

    constraint opcode_const{
      opcode<=7;
      opcode>=0;
    }

    function void print_transaction();
        $display("Writing to register location %0d: ", write_pointer);
        $display("  opcode = %0d (%s)", opcode, opcode.name);
        $display("  operand_a = %0d",   operand_a);
        $display("  operand_b = %0d\n", operand_b);
    endfunction: print_transaction

    task randomize_transaction();     //Task-ul consuma timp de rulare, functia nu consuma
        static int temp = 0;
        operand_a     = $random(seed)%16;                 // between -15 and 15
        operand_b     = $unsigned($random)%16;            // between 0 and 15
        opcode        = opcode_t'($unsigned($random)%8);  // between 0 and 7, cast to opcode_t type
        write_pointer = temp++;
    endtask
  endclass
  
  class Driver;
    virtual tb_ifc vifc;
    transaction trans;

    function new (virtual tb_ifc vifc);
      this.vifc = vifc;
      trans=new();
    endfunction  

    task reset_signals();
       vifc.cb.write_pointer <= 5'h00;      // initialize write pointer
       vifc.cb.read_pointer  <= 5'h1F;      // initialize read pointer
       vifc.cb.load_en       <= 1'b0;       // initialize load control line
       vifc.cb.reset_n       <= 1'b0;       // assert reset_n (active low)
       repeat (2) @(vifc.cb) ;      // hold in reset for 2 clock cycles
       vifc.cb.reset_n       <= 1'b1;       // assert reset_n (active low)
       $display("\nWriting values to register stack...");
			 @(vifc.cb) vifc.cb.load_en <= 1'b1;  // enable writing to register
    endtask


    function assign_signals();
       static int temp = 0;
       vifc.cb.operand_a <= trans.operand_a; 
	     vifc.cb.operand_b <= trans.operand_b;
       vifc.cb.opcode <= trans.opcode;
       vifc.cb.write_pointer <= temp++;
    endfunction

    task generate_transaction();
    $display("\n\n***********************************************************");
    $display(    "***  THIS IS NOT A SELF-CHECKING TESTBENCH (YET).  YOU  ***");
    $display(    "***  NEED TO VISUALLY VERIFY THAT THE OUTPUT VALUES     ***");
    $display(    "***  MATCH THE INPUT VALUES FOR EACH REGISTER LOCATION  ***");
    $display(    "***********************************************************");
    $display("\nReseting the instruction register...");

      //Reset
      reset_signals();
       
       $display("\nWriting values to register stack...");
			 @(vifc.cb) vifc.cb.load_en <= 1'b1;  // enable writing to register
       repeat (3) begin
       //Load
       @(vifc.cb)trans.randomize();
       assign_signals();
	     @(vifc.cb)trans.print_transaction();
       end
       @( vifc.cb) vifc.cb.load_en <= 1'b0;  // turn-off writing to register
    endtask

  endclass

  class Monitor;
    virtual tb_ifc vifc;

    function new (virtual tb_ifc vifc);
      this.vifc = vifc;
    endfunction  

     // read back and display same three register locations
     task read_results();
        $display("\nReading back the same register locations written...");
        for (int i=0; i<=2; i++) begin
        // A later lab will replace this loop with iterating through a
        // scoreboard to determine which address were written and the
        // expected values to be read back
          @(vifc.cb) vifc.cb.read_pointer <= i;
          @(vifc.cb) print_results;
        end
         @(vifc.cb) ;
          $display("\n***********************************************************");
          $display(  "***  THIS IS NOT A SELF-CHECKING TESTBENCH (YET).  YOU  ***");
          $display(  "***  NEED TO VISUALLY VERIFY THAT THE OUTPUT VALUES     ***");
          $display(  "***  MATCH THE INPUT VALUES FOR EACH REGISTER LOCATION  ***");
          $display(  "***********************************************************\n");
          $finish;
     endtask

    task print_results;
      $display("Read from register location %0d: ", vifc.cb.read_pointer);
      $display("  opcode = %0d (%s)", vifc.cb.instruction_word.opc, vifc.cb.instruction_word.opc.name);
      $display("  operand_a = %0d",   vifc.cb.instruction_word.op_a);
      $display("  operand_b = %0d\n", vifc.cb.instruction_word.op_b);
    endtask
  endclass

  initial begin

      Driver drv;
      Monitor mon;

      drv= new(io);
      mon= new(io);
      drv.generate_transaction();
      mon.read_results();
   
  end
  
  //   $display("\n\n***********************************************************");
  //   $display(    "***  THIS IS NOT A SELF-CHECKING TESTBENCH (YET).  YOU  ***");
  //   $display(    "***  NEED TO VISUALLY VERIFY THAT THE OUTPUT VALUES     ***");
  //   $display(    "***  MATCH THE INPUT VALUES FOR EACH REGISTER LOCATION  ***");
  //   $display(    "***********************************************************");

  //   $display("\nReseting the instruction register...");
  //   @io.cb
  //   io.cb.write_pointer <= 5'h00;      // initialize write pointer
  //   @io.cb
  //   io.cb.read_pointer  <= 5'h1F;      // initialize read pointer
  //   @io.cb
  //   io.cb.load_en       <= 1'b0;       // initialize load control line
  //   @io.cb
  //   io.cb.reset_n       <= 1'b0;       // assert reset_n (active low)
  //   @io.cb
  //   repeat (2) @(posedge io.cb) ;  // hold in reset for 2 clock cycles
  //   @io.cb
  //   io.cb.reset_n       <= 1'b1;       // assert reset_n (active low)

  //   $display("\nWriting values to register stack...");
  //   @(posedge io.cb) io.cb.load_en <= 1'b1;  // enable writing to register
  //   repeat (3) begin
  //     @(posedge io.cb) randomize_transaction;
  //     @(negedge io.cb) print_transaction;
  //   end
  //   @(posedge io.cb) io.cb.load_en <= 1'b0;  // turn-off writing to register

  //   // read back and display same three register locations
  //   $display("\nReading back the same register locations written...");
  //   for (int i=0; i<=2; i++) begin
  //     // A later lab will replace this loop with iterating through a
  //     // scoreboard to determine which address were written and the
  //     // expected values to be read back
  //     @(posedge io.cb) io.cb.read_pointer <= i;
  //     @(negedge io.cb) print_results;
  //   end

  //   @(posedge io.cb) ;
  //   $display("\n***********************************************************");
  //   $display(  "***  THIS IS NOT A SELF-CHECKING TESTBENCH (YET).  YOU  ***");
  //   $display(  "***  NEED TO VISUALLY VERIFY THAT THE OUTPUT VALUES     ***");
  //   $display(  "***  MATCH THE INPUT VALUES FOR EACH REGISTER LOCATION  ***");
  //   $display(  "***********************************************************\n");
  //   $finish;
  // end

  // function void randomize_transaction;
  //   // A later lab will replace this function with SystemVerilog
  //   // constrained random values
  //   //
  //   // The stactic temp variable is required in order to write to fixed
  //   // addresses of 0, 1 and 2.  This will be replaceed with randomizeed
  //   // write_pointer values in a later lab
  //   //
  //   static int temp = 0;
  //   io.cb.operand_a     <= $random(seed)%16;                 // between -15 and 15
  //   io.cb.operand_b     <= $unsigned($random)%16;            // between 0 and 15
  //   io.cb.opcode        <= opcode_t'($unsigned($random)%8);  // between 0 and 7, cast to opcode_t type
  //   io.cb.write_pointer <= temp++;
  // endfunction: randomize_transaction

  // function void print_transaction;
  //   $display("Writing to register location %0d: ", io.cb.write_pointer);
  //   $display("  opcode = %0d (%s)", io.cb.opcode, io.cb.opcode.name);
  //   $display("  operand_a = %0d",   io.cb.operand_a);
  //   $display("  operand_b = %0d\n", io.cb.operand_b);
  // endfunction: print_transaction

  // function void print_results;
  //   $display("Read from register location %0d: ", io.cb.read_pointer);
  //   $display("  opcode = %0d (%s)", io.cb.instruction_word.opc, io.cb.instruction_word.opc.name);
  //   $display("  operand_a = %0d",   io.cb.instruction_word.op_a);
  //   $display("  operand_b = %0d\n", io.cb.instruction_word.op_b);
  // endfunction: print_results

endmodule: instr_register_test
