-- raft.ads
-- Specification for the Raft consensus algorithm (State Machine Logic)
with Ada.Exceptions;

package Raft is

   type Node_Role is (Follower, Candidate, Leader);
   type Term_ID is new Natural;
   type Node_ID is new Natural; -- 0 represents None/Null
   type Log_Index is new Natural;

   type Log_Entry is record
      Term    : Term_ID;
      Command : Integer; -- Using integer as a placeholder for state machine commands
   end record;

   Max_Log_Size : constant := 1000;
   type Log_Array is array (Log_Index range 1 .. Max_Log_Size) of Log_Entry;

   -- Represents the state of a single Raft node
   type Raft_Node is record
      Id                     : Node_ID := 0;
      Role                   : Node_Role := Follower;
      Current_Term           : Term_ID := 0;
      Voted_For              : Node_ID := 0;
      
      Log                    : Log_Array;
      Log_Length             : Log_Index := 0;
      Commit_Index           : Log_Index := 0;
      Last_Applied           : Log_Index := 0;
      
      -- Timeouts and election simulation
      Election_Timeout_Ticks : Integer := 10;
      Current_Ticks          : Integer := 0;
      Total_Nodes            : Integer := 1;
      Votes_Received         : Integer := 0;
   end record;

   -- RPC arguments and results
   type Request_Vote_Args is record
      Term           : Term_ID;
      Candidate_Id   : Node_ID;
      Last_Log_Index : Log_Index;
      Last_Log_Term  : Term_ID;
   end record;

   type Request_Vote_Result is record
      Term         : Term_ID;
      Vote_Granted : Boolean;
   end record;

   type Append_Entries_Args is record
      Term           : Term_ID;
      Leader_Id      : Node_ID;
      Prev_Log_Index : Log_Index;
      Prev_Log_Term  : Term_ID;
      Entry_Present  : Boolean;
      Log_Entry_Data : Log_Entry;
      Leader_Commit  : Log_Index;
   end record;

   type Append_Entries_Result is record
      Term    : Term_ID;
      Success : Boolean;
   end record;

   -- Core Operations
   procedure Initialize (Node : out Raft_Node; Id : Node_ID; Nodes_Count : Integer);
   
   -- Simulates a timer tick. May trigger election if timeout is reached.
   procedure Tick (Node : in out Raft_Node);
   
   -- RPC Handlers
   procedure Handle_Request_Vote 
     (Node   : in out Raft_Node; 
      Args   : in Request_Vote_Args; 
      Result : out Request_Vote_Result);
      
   procedure Handle_Append_Entries 
     (Node   : in out Raft_Node; 
      Args   : in Append_Entries_Args; 
      Result : out Append_Entries_Result);

   -- Handles receiving vote replies during the Candidate phase
   procedure Receive_Vote_Reply 
     (Node   : in out Raft_Node; 
      Result : in Request_Vote_Result);

   -- Helper to get the term of the last log entry
   function Last_Log_Term (Node : Raft_Node) return Term_ID;

end Raft;
