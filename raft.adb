-- raft.adb
-- Implementation of the Raft consensus algorithm

package body Raft is

   procedure Initialize (Node : out Raft_Node; Id : Node_ID; Nodes_Count : Integer) is
   begin
      Node.Id := Id;
      Node.Role := Follower;
      Node.Current_Term := 0;
      Node.Voted_For := 0;
      Node.Log_Length := 0;
      Node.Commit_Index := 0;
      Node.Last_Applied := 0;
      Node.Election_Timeout_Ticks := 10;
      Node.Current_Ticks := 0;
      Node.Total_Nodes := Nodes_Count;
      Node.Votes_Received := 0;
   end Initialize;

   function Last_Log_Term (Node : Raft_Node) return Term_ID is
   begin
      if Node.Log_Length = 0 then
         return 0;
      else
         return Node.Log(Node.Log_Length).Term;
      end if;
   end Last_Log_Term;

   procedure Tick (Node : in out Raft_Node) is
   begin
      if Node.Role = Leader then
         -- Leaders send heartbeats, they don't timeout for elections
         return;
      end if;

      Node.Current_Ticks := Node.Current_Ticks + 1;
      
      if Node.Current_Ticks >= Node.Election_Timeout_Ticks then
         -- Timeout reached: Become Candidate
         Node.Role := Candidate;
         Node.Current_Term := Node.Current_Term + 1;
         Node.Voted_For := Node.Id;
         Node.Votes_Received := 1; -- Voted for self
         Node.Current_Ticks := 0; -- Reset timer
         
         -- If we are the only node, we immediately become leader
         if Node.Votes_Received * 2 > Node.Total_Nodes then
            Node.Role := Leader;
         end if;
      end if;
   end Tick;

   procedure Handle_Request_Vote 
     (Node   : in out Raft_Node; 
      Args   : in Request_Vote_Args; 
      Result : out Request_Vote_Result) is
      
      Log_Is_Up_To_Date : Boolean;
      My_Last_Term : Term_ID;
   begin
      -- 1. Reply false if term < currentTerm
      if Args.Term < Node.Current_Term then
         Result.Term := Node.Current_Term;
         Result.Vote_Granted := False;
         return;
      end if;

      -- If RPC request or response contains term T > currentTerm:
      -- set currentTerm = T, convert to follower
      if Args.Term > Node.Current_Term then
         Node.Current_Term := Args.Term;
         Node.Role := Follower;
         Node.Voted_For := 0;
      end if;

      -- Check if candidate's log is at least as up-to-date as receiver's log
      My_Last_Term := Last_Log_Term(Node);
      if Args.Last_Log_Term > My_Last_Term then
         Log_Is_Up_To_Date := True;
      elsif Args.Last_Log_Term = My_Last_Term and then Args.Last_Log_Index >= Node.Log_Length then
         Log_Is_Up_To_Date := True;
      else
         Log_Is_Up_To_Date := False;
      end if;

      -- 2. If votedFor is null or candidateId, and candidate's log is at least as up-to-date, grant vote
      if (Node.Voted_For = 0 or else Node.Voted_For = Args.Candidate_Id) and then Log_Is_Up_To_Date then
         Node.Voted_For := Args.Candidate_Id;
         Node.Current_Ticks := 0; -- Reset election timer when granting vote
         Result.Term := Node.Current_Term;
         Result.Vote_Granted := True;
      else
         Result.Term := Node.Current_Term;
         Result.Vote_Granted := False;
      end if;
   end Handle_Request_Vote;

   procedure Handle_Append_Entries 
     (Node   : in out Raft_Node; 
      Args   : in Append_Entries_Args; 
      Result : out Append_Entries_Result) is
   begin
      -- 1. Reply false if term < currentTerm
      if Args.Term < Node.Current_Term then
         Result.Term := Node.Current_Term;
         Result.Success := False;
         return;
      end if;

      -- If valid leader (Term >= Current_Term), revert to Follower
      Node.Current_Term := Args.Term;
      Node.Role := Follower;
      Node.Current_Ticks := 0; -- Reset election timer on heartbeat
      
      -- 2. Reply false if log doesn't contain an entry at prevLogIndex whose term matches prevLogTerm
      if Args.Prev_Log_Index > 0 then
         if Node.Log_Length < Args.Prev_Log_Index then
            Result.Term := Node.Current_Term;
            Result.Success := False;
            return;
         end if;
         
         if Node.Log(Args.Prev_Log_Index).Term /= Args.Prev_Log_Term then
            -- Note: In a full implementation, we'd delete this and following conflicting entries
            Result.Term := Node.Current_Term;
            Result.Success := False;
            return;
         end if;
      end if;

      -- 3. & 4. Append any new entries not already in the log
      if Args.Entry_Present then
         Node.Log_Length := Args.Prev_Log_Index + 1;
         Node.Log(Node.Log_Length) := Args.Entry;
      end if;

      -- 5. If leaderCommit > commitIndex, set commitIndex = min(leaderCommit, index of last new entry)
      if Args.Leader_Commit > Node.Commit_Index then
         if Args.Leader_Commit < Node.Log_Length then
            Node.Commit_Index := Args.Leader_Commit;
         else
            Node.Commit_Index := Node.Log_Length;
         end if;
      end if;

      Result.Term := Node.Current_Term;
      Result.Success := True;
   end Handle_Append_Entries;

   procedure Receive_Vote_Reply 
     (Node   : in out Raft_Node; 
      Result : in Request_Vote_Result) is
   begin
      if Node.Role /= Candidate then
         return; -- Only Candidates care about votes
      end if;

      if Result.Term > Node.Current_Term then
         Node.Current_Term := Result.Term;
         Node.Role := Follower;
         Node.Voted_For := 0;
         return;
      end if;

      if Result.Vote_Granted then
         Node.Votes_Received := Node.Votes_Received + 1;
         -- Check for majority
         if Node.Votes_Received * 2 > Node.Total_Nodes then
            Node.Role := Leader;
         end if;
      end if;
   end Receive_Vote_Reply;

end Raft;
