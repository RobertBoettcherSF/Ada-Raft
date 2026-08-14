-- tests.adb
-- Validation and Verification test suite for the Raft implementation
with Ada.Text_IO; use Ada.Text_IO;
with Ada.Assertions; use Ada.Assertions;
with Raft; use Raft;

procedure Tests is
   My_Node : Raft_Node;
   RV_Args : Request_Vote_Args;
   RV_Res  : Request_Vote_Result;
   AE_Args : Append_Entries_Args;
   AE_Res  : Append_Entries_Result;
begin
   Put_Line ("Starting Raft Consensus Tests...");
   Put_Line ("==================================");

   -- TEST 1
   Put_Line ("TEST 1 - Node Initialization");
   Initialize (My_Node, Id => 1, Nodes_Count => 3);
   Put_Line ("  1.1 Assert Initial Role is Follower");
   Assert (My_Node.Role = Follower);
   Put_Line ("  1.2 Assert Initial Term is 0");
   Assert (My_Node.Current_Term = 0);
   Put_Line ("      PASS");

   -- TEST 2
   Put_Line ("TEST 2 - Tick behavior (No Timeout)");
   Tick (My_Node);
   Put_Line ("  2.1 Assert ticks increment");
   Assert (My_Node.Current_Ticks = 1);
   Put_Line ("  2.2 Assert Role remains Follower");
   Assert (My_Node.Role = Follower);
   Put_Line ("      PASS");

   -- TEST 3
   Put_Line ("TEST 3 - Election Timeout Transition");
   for I in 1 .. 9 loop Tick (My_Node); end loop;
   Put_Line ("  3.1 Assert Role changed to Candidate upon timeout");
   Assert (My_Node.Role = Candidate);
   Put_Line ("  3.2 Assert Term incremented");
   Assert (My_Node.Current_Term = 1);
   Put_Line ("      PASS");

   -- TEST 4
   Put_Line ("TEST 4 - Candidate Self-Voting");
   Put_Line ("  4.1 Assert Voted_For is self");
   Assert (My_Node.Voted_For = 1);
   Put_Line ("  4.2 Assert Votes_Received = 1");
   Assert (My_Node.Votes_Received = 1);
   Put_Line ("      PASS");

   -- TEST 5
   Put_Line ("TEST 5 - Receive RequestVote from stale term");
   RV_Args.Term := 0;
   RV_Args.Candidate_Id := 2;
   RV_Args.Last_Log_Index := 0;
   RV_Args.Last_Log_Term := 0;
   Handle_Request_Vote (My_Node, RV_Args, RV_Res);
   Put_Line ("  5.1 Assert Vote Rejected");
   Assert (not RV_Res.Vote_Granted);
   Put_Line ("      PASS");

   -- TEST 6
   Put_Line ("TEST 6 - Receive RequestVote from newer term");
   RV_Args.Term := 2;
   RV_Args.Candidate_Id := 3;
   RV_Args.Last_Log_Index := 0;
   RV_Args.Last_Log_Term := 0;
   Handle_Request_Vote (My_Node, RV_Args, RV_Res);
   Put_Line ("  6.1 Assert Vote Granted");
   Assert (RV_Res.Vote_Granted);
   Put_Line ("  6.2 Assert node reverted to Follower");
   Assert (My_Node.Role = Follower);
   Put_Line ("  6.3 Assert node updated its term");
   Assert (My_Node.Current_Term = 2);
   Put_Line ("      PASS");

   -- TEST 7
   Put_Line ("TEST 7 - Double Voting Prevention (Same Term)");
   RV_Args.Term := 2;
   RV_Args.Candidate_Id := 2;
   RV_Args.Last_Log_Index := 0;
   RV_Args.Last_Log_Term := 0;
   Handle_Request_Vote (My_Node, RV_Args, RV_Res);
   Put_Line ("  7.1 Assert second vote in same term rejected");
   Assert (not RV_Res.Vote_Granted);
   Put_Line ("      PASS");

   -- TEST 8
   Put_Line ("TEST 8 - Reaching Majority becomes Leader");
   Initialize (My_Node, Id => 1, Nodes_Count => 3);
   for I in 1 .. 10 loop Tick (My_Node); end loop;
   RV_Res.Term := 1;
   RV_Res.Vote_Granted := True;
   Receive_Vote_Reply (My_Node, RV_Res);
   Put_Line ("  8.1 Assert 2/3 votes -> Leader Role");
   Assert (My_Node.Role = Leader);
   Put_Line ("      PASS");

   -- TEST 9
   Put_Line ("TEST 9 - AppendEntries heartbeats behavior");
   Initialize (My_Node, Id => 1, Nodes_Count => 3);
   My_Node.Current_Term := 1;
   My_Node.Current_Ticks := 5;
   AE_Args.Term := 1;
   AE_Args.Leader_Id := 2;
   AE_Args.Prev_Log_Index := 0;
   AE_Args.Prev_Log_Term := 0;
   AE_Args.Entry_Present := False;
   AE_Args.Entry := (Term => 0, Command => 0);
   AE_Args.Leader_Commit := 0;
   Handle_Append_Entries (My_Node, AE_Args, AE_Res);
   Put_Line ("  9.1 Assert Heartbeat resets election ticks");
   Assert (My_Node.Current_Ticks = 0);
   Put_Line ("  9.2 Assert Success true for valid heartbeat");
   Assert (AE_Res.Success);
   Put_Line ("      PASS");

   -- TEST 10
   Put_Line ("TEST 10 - AppendEntries from stale leader");
   My_Node.Current_Term := 3;
   AE_Args.Term := 2;
   Handle_Append_Entries (My_Node, AE_Args, AE_Res);
   Put_Line ("  10.1 Assert stale leader request rejected");
   Assert (not AE_Res.Success);
   Put_Line ("      PASS");

   -- TEST 11
   Put_Line ("TEST 11 - Single Log Entry Append");
   AE_Args.Term := 3;
   AE_Args.Leader_Id := 2;
   AE_Args.Prev_Log_Index := 0;
   AE_Args.Prev_Log_Term := 0;
   AE_Args.Entry_Present := True;
   AE_Args.Entry := (Term => 3, Command => 99);
   AE_Args.Leader_Commit := 0;
   Handle_Append_Entries (My_Node, AE_Args, AE_Res);
   Put_Line ("  11.1 Assert successful append");
   Assert (AE_Res.Success);
   Put_Line ("  11.2 Assert Log Length updated to 1");
   Assert (My_Node.Log_Length = 1);
   Put_Line ("  11.3 Assert Log data matches");
   Assert (My_Node.Log(1).Command = 99);
   Put_Line ("      PASS");

   -- TEST 12
   Put_Line ("TEST 12 - PrevLogIndex mismatch Rejection");
   AE_Args.Term := 3;
   AE_Args.Leader_Id := 2;
   AE_Args.Prev_Log_Index := 2;
   AE_Args.Prev_Log_Term := 3;
   AE_Args.Entry_Present := True;
   AE_Args.Entry := (Term => 3, Command => 100);
   AE_Args.Leader_Commit := 0;
   Handle_Append_Entries (My_Node, AE_Args, AE_Res);
   Put_Line ("  12.1 Assert PrevLogIndex check rejected the entry");
   Assert (not AE_Res.Success);
   Put_Line ("      PASS");

   -- TEST 13
   Put_Line ("TEST 13 - Commit Index Advancement");
   AE_Args.Term := 3;
   AE_Args.Leader_Id := 2;
   AE_Args.Prev_Log_Index := 1;
   AE_Args.Prev_Log_Term := 3;
   AE_Args.Entry_Present := True;
   AE_Args.Entry := (Term => 3, Command => 100);
   AE_Args.Leader_Commit := 2;
   Handle_Append_Entries (My_Node, AE_Args, AE_Res);
   Put_Line ("  13.1 Assert successful append at index 2");
   Assert (AE_Res.Success);
   Put_Line ("  13.2 Assert commit index matches leader");
   Assert (My_Node.Commit_Index = 2);
   Put_Line ("      PASS");

   -- TEST 14
   Put_Line ("TEST 14 - Leader stepping down on newer term");
   Initialize (My_Node, Id => 1, Nodes_Count => 3);
   My_Node.Role := Leader;
   My_Node.Current_Term := 3;
   AE_Args.Term := 4;
   AE_Args.Leader_Id := 2;
   AE_Args.Prev_Log_Index := 0;
   AE_Args.Prev_Log_Term := 0;
   AE_Args.Entry_Present := False;
   AE_Args.Entry := (Term => 0, Command => 0);
   AE_Args.Leader_Commit := 0;
   Handle_Append_Entries (My_Node, AE_Args, AE_Res);
   Put_Line ("  14.1 Assert Leader reverted to Follower");
   Assert (My_Node.Role = Follower);
   Put_Line ("      PASS");

   Put_Line ("==================================");
   Put_Line ("ALL 14 TESTS PASSED. Assumptions disproved. Code operates correctly.");
end Tests;
