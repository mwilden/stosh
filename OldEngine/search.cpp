/*
  Stockfish, a UCI chess playing engine derived from Glaurung 2.1
  Copyright (C) 2004-2008 Tord Romstad (Glaurung author)
  Copyright (C) 2008-2010 Marco Costalba, Joona Kiiski, Tord Romstad

  Stockfish is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  Stockfish is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/


////
//// Includes
////

#include <cassert>
#include <cmath>
#include <cstring>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <sstream>

#include "bitcount.h"
#include "book.h"
#include "evaluate.h"
#include "history.h"
#include "iphone.h"
#include "misc.h"
#include "movegen.h"
#include "movepick.h"
#include "lock.h"
#include "san.h"
#include "search.h"
#include "thread.h"
#include "tt.h"
#include "ucioption.h"

using std::cout;
using std::endl;

////
//// Local definitions
////

namespace {

  /// Types


  // ThreadsManager class is used to handle all the threads related stuff in search,
  // init, starting, parking and, the most important, launching a slave thread at a
  // split point are what this class does. All the access to shared thread data is
  // done through this class, so that we avoid using global variables instead.

  class ThreadsManager {
    /* As long as the single ThreadsManager object is defined as a global we don't
       need to explicitly initialize to zero its data members because variables with
       static storage duration are automatically set to zero before enter main()
    */
  public:
    void init_threads();
    void exit_threads();

    int active_threads() const { return ActiveThreads; }
    void set_active_threads(int newActiveThreads) { ActiveThreads = newActiveThreads; }
    void incrementNodeCounter(int threadID) { threads[threadID].nodes++; }
    void incrementBetaCounter(Color us, Depth d, int threadID) { threads[threadID].betaCutOffs[us] += unsigned(d); }

    void resetNodeCounters();
    void resetBetaCounters();
    int64_t nodes_searched() const;
    void get_beta_counters(Color us, int64_t& our, int64_t& their) const;
    bool available_thread_exists(int master) const;
    bool thread_is_available(int slave, int master) const;
    bool thread_should_stop(int threadID) const;
    void wake_sleeping_threads();
    void put_threads_to_sleep();
    void idle_loop(int threadID, SplitPoint* waitSp);
    bool split(const Position& pos, SearchStack* ss, int ply, Value* alpha, const Value beta, Value* bestValue,
               Depth depth, bool mateThreat, int* moves, MovePicker* mp, int master, bool pvNode);

  private:
    friend void poll();

    int ActiveThreads;
    volatile bool AllThreadsShouldExit, AllThreadsShouldSleep;
    Thread threads[MAX_THREADS];
    SplitPoint SplitPointStack[MAX_THREADS][ACTIVE_SPLIT_POINTS_MAX];

    Lock MPLock, WaitLock;

#if !defined(_MSC_VER)
    pthread_cond_t WaitCond;
#else
    HANDLE SitIdleEvent[MAX_THREADS];
#endif

  };


  // RootMove struct is used for moves at the root at the tree. For each
  // root move, we store a score, a node count, and a PV (really a refutation
  // in the case of moves which fail low).

  struct RootMove {

    RootMove() { nodes = cumulativeNodes = ourBeta = theirBeta = 0ULL; }

    // RootMove::operator<() is the comparison function used when
    // sorting the moves. A move m1 is considered to be better
    // than a move m2 if it has a higher score, or if the moves
    // have equal score but m1 has the higher node count.
    bool operator<(const RootMove& m) const {

        return score != m.score ? score < m.score : theirBeta <= m.theirBeta;
    }

    Move move;
    Value score;
    int64_t nodes, cumulativeNodes, ourBeta, theirBeta;
    Move pv[PLY_MAX_PLUS_2];
  };


  // The RootMoveList class is essentially an array of RootMove objects, with
  // a handful of methods for accessing the data in the individual moves.

  class RootMoveList {

  public:
    RootMoveList(Position& pos, Move searchMoves[]);

    int move_count() const { return count; }
    Move get_move(int moveNum) const { return moves[moveNum].move; }
    Value get_move_score(int moveNum) const { return moves[moveNum].score; }
    void set_move_score(int moveNum, Value score) { moves[moveNum].score = score; }
    Move get_move_pv(int moveNum, int i) const { return moves[moveNum].pv[i]; }
    int64_t get_move_cumulative_nodes(int moveNum) const { return moves[moveNum].cumulativeNodes; }

    void set_move_nodes(int moveNum, int64_t nodes);
    void set_beta_counters(int moveNum, int64_t our, int64_t their);
    void set_move_pv(int moveNum, const Move pv[]);
    void sort();
    void sort_multipv(int n);

  private:
    static const int MaxRootMoves = 500;
    RootMove moves[MaxRootMoves];
    int count;
  };


  /// Adjustments

  // Step 6. Razoring

  // Maximum depth for razoring
  const Depth RazorDepth = 4 * OnePly;

  // Dynamic razoring margin based on depth
  inline Value razor_margin(Depth d) { return Value(0x200 + 0x10 * int(d)); }

  // Step 8. Null move search with verification search

  // Null move margin. A null move search will not be done if the static
  // evaluation of the position is more than NullMoveMargin below beta.
  const Value NullMoveMargin = Value(0x200);

  // Maximum depth for use of dynamic threat detection when null move fails low
  const Depth ThreatDepth = 5 * OnePly;

  // Step 9. Internal iterative deepening

  // Minimum depth for use of internal iterative deepening
  const Depth IIDDepthAtPVNodes = 5 * OnePly;
  const Depth IIDDepthAtNonPVNodes = 8 * OnePly;

  // At Non-PV nodes we do an internal iterative deepening search
  // when the static evaluation is at most IIDMargin below beta.
  const Value IIDMargin = Value(0x100);

  // Step 11. Decide the new search depth

  // Extensions. Configurable UCI options
  // Array index 0 is used at non-PV nodes, index 1 at PV nodes.
  Depth CheckExtension[2], SingleEvasionExtension[2], PawnPushTo7thExtension[2];
  Depth PassedPawnExtension[2], PawnEndgameExtension[2], MateThreatExtension[2];

  // Minimum depth for use of singular extension
  const Depth SingularExtensionDepthAtPVNodes = 6 * OnePly;
  const Depth SingularExtensionDepthAtNonPVNodes = 8 * OnePly;

  // If the TT move is at least SingularExtensionMargin better then the
  // remaining ones we will extend it.
  const Value SingularExtensionMargin = Value(0x20);

  // Step 12. Futility pruning

  // Futility margin for quiescence search
  const Value FutilityMarginQS = Value(0x80);

  // Futility lookup tables (initialized at startup) and their getter functions
  int32_t FutilityMarginsMatrix[16][64]; // [depth][moveNumber]
  int FutilityMoveCountArray[32]; // [depth]

  inline Value futility_margin(Depth d, int mn) { return Value(d < 7 * OnePly ? FutilityMarginsMatrix[Max(d, 0)][Min(mn, 63)] : 2 * VALUE_INFINITE); }
  inline int futility_move_count(Depth d) { return d < 16 * OnePly ? FutilityMoveCountArray[d] : 512; }

  // Step 14. Reduced search

  // Reduction lookup tables (initialized at startup) and their getter functions
  int8_t    PVReductionMatrix[64][64]; // [depth][moveNumber]
  int8_t NonPVReductionMatrix[64][64]; // [depth][moveNumber]

  inline Depth    pv_reduction(Depth d, int mn) { return (Depth)    PVReductionMatrix[Min(d / 2, 63)][Min(mn, 63)]; }
  inline Depth nonpv_reduction(Depth d, int mn) { return (Depth) NonPVReductionMatrix[Min(d / 2, 63)][Min(mn, 63)]; }

  // Common adjustments

  // Search depth at iteration 1
  const Depth InitialDepth = OnePly;

  // Easy move margin. An easy move candidate must be at least this much
  // better than the second best move.
  const Value EasyMoveMargin = Value(0x200);

  // Last seconds noise filtering (LSN)
  const bool UseLSNFiltering = false;
  const int LSNTime = 4000; // In milliseconds
  const Value LSNValue = value_from_centipawns(200);
  bool loseOnTime = false;

  // Adjustable playing strength
  int Slowdown = 0;
  const int SlowdownArray[14] = {
     14, 30, 46, 70, 115, 170, 240, 330, 453, 610, 793, 1027, 1284, 1605
  };
  const int MaxStrength = 25;
  int Blunder = 0;


  /// Global variables

  // Iteration counter
  int Iteration;

  // Scores and number of times the best move changed for each iteration
  Value ValueByIteration[PLY_MAX_PLUS_2];
  int BestMoveChangesByIteration[PLY_MAX_PLUS_2];

  // Search window management
  int AspirationDelta;

  // MultiPV mode
  int MultiPV;

  // Time managment variables
  int SearchStartTime, MaxNodes, MaxDepth, MaxSearchTime;
  int AbsoluteMaxSearchTime, ExtraSearchTime, ExactMaxTime;
  bool UseTimeManagement, InfiniteSearch, PonderSearch, StopOnPonderhit;
  bool FirstRootMove, AbortSearch, Quit, AspirationFailLow, ZugDetection;

  // Log file
  bool UseLogFile;
  std::ofstream LogFile;

  // Multi-threads related variables
  Depth MinimumSplitDepth;
  int MaxThreadsPerSplitPoint;
  ThreadsManager TM;

  // Node counters, used only by thread[0] but try to keep in different cache
  // lines (64 bytes each) from the heavy multi-thread read accessed variables.
  int NodesSincePoll;
  int NodesBetweenPolls = 30000;

  // History table
  History H;

  /// Local functions

  Value id_loop(const Position& pos, Move searchMoves[]);
  Value root_search(Position& pos, SearchStack ss[], RootMoveList& rml, Value* alphaPtr, Value* betaPtr);
  Value search_pv(Position& pos, SearchStack ss[], Value alpha, Value beta, Depth depth, int ply, int threadID);
  Value search(Position& pos, SearchStack ss[], Value beta, Depth depth, int ply, bool allowNullmove, int threadID, Move excludedMove = MOVE_NONE);
  Value qsearch(Position& pos, SearchStack ss[], Value alpha, Value beta, Depth depth, int ply, int threadID);
  void sp_search(SplitPoint* sp, int threadID);
  void sp_search_pv(SplitPoint* sp, int threadID);
  void init_node(const Position& pos, SearchStack ss[], int ply, int threadID);
  void update_pv(SearchStack ss[], int ply);
  void sp_update_pv(SearchStack* pss, SearchStack ss[], int ply);
  bool connected_moves(const Position& pos, Move m1, Move m2);
  bool value_is_mate(Value value);
  bool move_is_killer(Move m, const SearchStack& ss);
  Depth extension(const Position&, Move, bool, bool, bool, bool, bool, bool*);
  bool ok_to_do_nullmove(const Position& pos);
  bool ok_to_prune(const Position& pos, Move m, Move threat);
  bool ok_to_use_TT(const TTEntry* tte, Depth depth, Value beta, int ply, bool allowNullmove);
  Value refine_eval(const TTEntry* tte, Value defaultEval, int ply);
  void update_history(const Position& pos, Move move, Depth depth, Move movesSearched[], int moveCount);
  void update_killers(Move m, SearchStack& ss);
  void update_gains(const Position& pos, Move move, Value before, Value after);
  void slowdown(const Position& pos);
  int blunder_modulus(const Position& pos, Move m, Depth d);

  int current_search_time();
  int nps();
  void poll();
  void ponderhit();
  void wait_for_stop_or_ponderhit();
  void init_ss_array(SearchStack ss[]);
  void print_pv_info(const Position& pos, SearchStack ss[], Value alpha, Value beta, Value value);

#if !defined(_MSC_VER)
  void *init_thread(void *threadID);
#else
  DWORD WINAPI init_thread(LPVOID threadID);
#endif

}


////
//// Functions
////

/// init_threads(), exit_threads() and nodes_searched() are helpers to
/// give accessibility to some TM methods from outside of current file.

void init_threads() { TM.init_threads(); }
void exit_threads() { TM.exit_threads(); }
int64_t nodes_searched() { return TM.nodes_searched(); }


/// perft() is our utility to verify move generation is bug free. All the legal
/// moves up to given depth are generated and counted and the sum returned.

int perft(Position& pos, Depth depth)
{
    StateInfo st;
    Move move;
    int sum = 0;
    MovePicker mp(pos, MOVE_NONE, depth, H);

    // If we are at the last ply we don't need to do and undo
    // the moves, just to count them.
    if (depth <= OnePly) // Replace with '<' to test also qsearch
    {
        while (mp.get_next_move()) sum++;
        return sum;
    }

    // Loop through all legal moves
    CheckInfo ci(pos);
    while ((move = mp.get_next_move()) != MOVE_NONE)
    {
        pos.do_move(move, st, ci, pos.move_is_check(move, ci));
        sum += perft(pos, depth - OnePly);
        pos.undo_move(move);
    }
    return sum;
}


/// think() is the external interface to Stockfish's search, and is called when
/// the program receives the UCI 'go' command. It initializes various
/// search-related global variables, and calls root_search(). It returns false
/// when a quit command is received during the search.

bool think(const Position& pos, bool infinite, bool ponder, int side_to_move,
           int time[], int increment[], int movesToGo, int maxDepth,
           int maxNodes, int maxTime, Move searchMoves[]) {

  // Initialize global search variables
  StopOnPonderhit = AbortSearch = Quit = AspirationFailLow = false;
  MaxSearchTime = AbsoluteMaxSearchTime = ExtraSearchTime = 0;
  NodesSincePoll = 0;
  TM.resetNodeCounters();
  SearchStartTime = get_system_time();
  ExactMaxTime = maxTime;
  MaxDepth = maxDepth;
  MaxNodes = maxNodes;
  InfiniteSearch = infinite;
  PonderSearch = ponder;
  UseTimeManagement = !ExactMaxTime && !MaxDepth && !MaxNodes && !InfiniteSearch;

  // Look for a book move, only during games, not tests
  if (UseTimeManagement && get_option_value_bool("OwnBook"))
  {
      if (get_option_value_string("Book File") != OpeningBook.file_name())
          OpeningBook.open(get_option_value_string("Book File"));

      Move bookMove = OpeningBook.get_move(pos);
      if (bookMove != MOVE_NONE)
      {
          if (PonderSearch)
              wait_for_stop_or_ponderhit();

          cout << "bestmove " << bookMove << endl;
          return true;
      }
  }

  // Reset loseOnTime flag at the beginning of a new game
  if (button_was_pressed("New Game"))
      loseOnTime = false;

  // Read UCI option values
  TT.set_size(get_option_value_int("Hash"));
  if (button_was_pressed("Clear Hash"))
      TT.clear();

  CheckExtension[1]         = Depth(get_option_value_int("Check Extension (PV nodes)"));
  CheckExtension[0]         = Depth(get_option_value_int("Check Extension (non-PV nodes)"));
  SingleEvasionExtension[1] = Depth(get_option_value_int("Single Evasion Extension (PV nodes)"));
  SingleEvasionExtension[0] = Depth(get_option_value_int("Single Evasion Extension (non-PV nodes)"));
  PawnPushTo7thExtension[1] = Depth(get_option_value_int("Pawn Push to 7th Extension (PV nodes)"));
  PawnPushTo7thExtension[0] = Depth(get_option_value_int("Pawn Push to 7th Extension (non-PV nodes)"));
  PassedPawnExtension[1]    = Depth(get_option_value_int("Passed Pawn Extension (PV nodes)"));
  PassedPawnExtension[0]    = Depth(get_option_value_int("Passed Pawn Extension (non-PV nodes)"));
  PawnEndgameExtension[1]   = Depth(get_option_value_int("Pawn Endgame Extension (PV nodes)"));
  PawnEndgameExtension[0]   = Depth(get_option_value_int("Pawn Endgame Extension (non-PV nodes)"));
  MateThreatExtension[1]    = Depth(get_option_value_int("Mate Threat Extension (PV nodes)"));
  MateThreatExtension[0]    = Depth(get_option_value_int("Mate Threat Extension (non-PV nodes)"));

  MinimumSplitDepth       = get_option_value_int("Minimum Split Depth") * OnePly;
  MaxThreadsPerSplitPoint = get_option_value_int("Maximum Number of Threads per Split Point");
  MultiPV                 = get_option_value_int("MultiPV");
  Chess960                = get_option_value_bool("UCI_Chess960");
  UseLogFile              = get_option_value_bool("Use Search Log");
  ZugDetection            = get_option_value_bool("Zugzwang detection"); // To be removed after 1.7.1

  if (UseLogFile)
      LogFile.open(get_option_value_string("Search Log Filename").c_str(), std::ios::out | std::ios::app);

  read_weights(pos.side_to_move());

  // Set playing strength
  if (get_option_value_bool("UCI_LimitStrength"))
  {
      Strength = (get_option_value_int("UCI_Elo") - 2100) / 25;
      // Strength is now an integer in the range -66 .. 14
      Blunder = 0;
      if (Strength == MaxStrength) Slowdown = 0;
      else if (Strength >= 0) Slowdown = SlowdownArray[Max(0, 13-Strength)];
      else Slowdown = SlowdownArray[13], Blunder = (53+Strength)*(53+Strength);
  }
  else
      Strength = MaxStrength, Slowdown = 0;

  // Set the number of active threads
  int newActiveThreads = get_option_value_int("Threads");
  if (newActiveThreads != TM.active_threads())
  {
      TM.set_active_threads(newActiveThreads);
      init_eval(TM.active_threads());
  }

  // Wake up sleeping threads
  TM.wake_sleeping_threads();

  // Set thinking time
  int myTime = time[side_to_move];
  int myIncrement = increment[side_to_move];
  if (UseTimeManagement)
  {
      if (!movesToGo) // Sudden death time control
      {
          if (myIncrement)
          {
              MaxSearchTime = myTime / 30 + myIncrement;
              AbsoluteMaxSearchTime = Max(myTime / 4, myIncrement - 100);
          }
          else // Blitz game without increment
          {
              MaxSearchTime = myTime / 30;
              AbsoluteMaxSearchTime = myTime / 8;
          }
      }
      else // (x moves) / (y minutes)
      {
          if (movesToGo == 1)
          {
              MaxSearchTime = myTime / 2;
              AbsoluteMaxSearchTime = (myTime > 3000)? (myTime - 500) : ((myTime * 3) / 4);
          }
          else
          {
              MaxSearchTime = myTime / Min(movesToGo, 20);
              AbsoluteMaxSearchTime = Min((4 * myTime) / movesToGo, myTime / 3);
          }
      }

      if (get_option_value_bool("Ponder"))
      {
          MaxSearchTime += MaxSearchTime / 4;
          MaxSearchTime = Min(MaxSearchTime, AbsoluteMaxSearchTime);
      }
  }

  // Set best NodesBetweenPolls interval to avoid lagging under
  // heavy time pressure.
  if (MaxNodes)
      NodesBetweenPolls = Min(MaxNodes, 30000);
  else if (myTime && myTime < 1000)
      NodesBetweenPolls = 1000;
  else if (myTime && myTime < 5000)
      NodesBetweenPolls = 5000;
  else
      NodesBetweenPolls = 30000;

#if defined(IPHONE_GLAURUNG)
  NodesBetweenPolls /= 30;
#endif

  // Write search information to log file
  if (UseLogFile)
      LogFile << "Searching: " << pos.to_fen() << endl
              << "infinite: "  << infinite
              << " ponder: "   << ponder
              << " time: "     << myTime
              << " increment: " << myIncrement
              << " moves to go: " << movesToGo << endl;

  // LSN filtering. Used only for developing purposes, disabled by default
  if (   UseLSNFiltering
      && loseOnTime)
  {
      // Step 2. If after last move we decided to lose on time, do it now!
       while (SearchStartTime + myTime + 1000 > get_system_time())
           /* wait here */;
  }

  // We're ready to start thinking. Call the iterative deepening loop function
  Value v = id_loop(pos, searchMoves);

  if (UseLSNFiltering)
  {
      // Step 1. If this is sudden death game and our position is hopeless,
      // decide to lose on time.
      if (   !loseOnTime // If we already lost on time, go to step 3.
          && myTime < LSNTime
          && myIncrement == 0
          && movesToGo == 0
          && v < -LSNValue)
      {
          loseOnTime = true;
      }
      else if (loseOnTime)
      {
          // Step 3. Now after stepping over the time limit, reset flag for next match.
          loseOnTime = false;
      }
  }

  if (UseLogFile)
      LogFile.close();

  TM.put_threads_to_sleep();

  return !Quit;
}


/// init_search() is called during startup. It initializes various lookup tables

void init_search() {

  // Init our reduction lookup tables
  for (int i = 1; i < 64; i++) // i == depth (OnePly = 1)
      for (int j = 1; j < 64; j++) // j == moveNumber
      {
          double    pvRed = 0.5 + log(double(i)) * log(double(j)) / 6.0;
          double nonPVRed = 0.5 + log(double(i)) * log(double(j)) / 3.0;
          PVReductionMatrix[i][j]    = (int8_t) (   pvRed >= 1.0 ? floor(   pvRed * int(OnePly)) : 0);
          NonPVReductionMatrix[i][j] = (int8_t) (nonPVRed >= 1.0 ? floor(nonPVRed * int(OnePly)) : 0);
      }

  // Init futility margins array
  for (int i = 0; i < 16; i++) // i == depth (OnePly = 2)
      for (int j = 0; j < 64; j++) // j == moveNumber
      {
          // FIXME: test using log instead of BSR
          FutilityMarginsMatrix[i][j] = (i < 2 ? 0 : 112 * bitScanReverse32(i * i / 2)) - 8 * j;
      }

  // Init futility move count array
  for (int i = 0; i < 32; i++) // i == depth (OnePly = 2)
      FutilityMoveCountArray[i] = 3 + (1 << (3 * i / 8));
}


// SearchStack::init() initializes a search stack. Used at the beginning of a
// new search from the root.
void SearchStack::init(int ply) {

  pv[ply] = pv[ply + 1] = MOVE_NONE;
  currentMove = threatMove = MOVE_NONE;
  reduction = Depth(0);
  eval = VALUE_NONE;
}

void SearchStack::initKillers() {

  mateKiller = MOVE_NONE;
  for (int i = 0; i < KILLER_MAX; i++)
      killers[i] = MOVE_NONE;
}

namespace {

  // id_loop() is the main iterative deepening loop. It calls root_search
  // repeatedly with increasing depth until the allocated thinking time has
  // been consumed, the user stops the search, or the maximum search depth is
  // reached.

  Value id_loop(const Position& pos, Move searchMoves[]) {

    Position p(pos);
    SearchStack ss[PLY_MAX_PLUS_2];
    Move EasyMove = MOVE_NONE;
    Value value, alpha = -VALUE_INFINITE, beta = VALUE_INFINITE;

    // Moves to search are verified, copied, scored and sorted
    RootMoveList rml(p, searchMoves);

    // Handle special case of searching on a mate/stale position
    if (rml.move_count() == 0)
    {
        if (PonderSearch)
            wait_for_stop_or_ponderhit();

        return pos.is_check() ? -VALUE_MATE : VALUE_DRAW;
    }

    // Print RootMoveList startup scoring to the standard output,
    // so to output information also for iteration 1.
    cout << "info depth " << 1
         << "\ninfo depth " << 1
         << " score " << value_to_string(rml.get_move_score(0))
         << " time " << current_search_time()
         << " nodes " << TM.nodes_searched()
         << " nps " << nps()
         << " pv " << rml.get_move(0) << "\n";

    // Initialize
    TT.new_search();
    H.clear();
    init_ss_array(ss);
    ValueByIteration[1] = rml.get_move_score(0);
    Iteration = 1;

    // Is one move significantly better than others after initial scoring ?
    if (   rml.move_count() == 1
        || rml.get_move_score(0) > rml.get_move_score(1) + EasyMoveMargin)
        EasyMove = rml.get_move(0);

    // Iterative deepening loop
    while (Iteration < PLY_MAX)
    {
        // Initialize iteration
        Iteration++;
        BestMoveChangesByIteration[Iteration] = 0;

        cout << "info depth " << Iteration << endl;

        // Calculate dynamic aspiration window based on previous iterations
        if (MultiPV == 1 && Iteration >= 6 && abs(ValueByIteration[Iteration - 1]) < VALUE_KNOWN_WIN)
        {
            int prevDelta1 = ValueByIteration[Iteration - 1] - ValueByIteration[Iteration - 2];
            int prevDelta2 = ValueByIteration[Iteration - 2] - ValueByIteration[Iteration - 3];

            AspirationDelta = Max(abs(prevDelta1) + abs(prevDelta2) / 2, 16);
            AspirationDelta = (AspirationDelta + 7) / 8 * 8; // Round to match grainSize

            alpha = Max(ValueByIteration[Iteration - 1] - AspirationDelta, -VALUE_INFINITE);
            beta  = Min(ValueByIteration[Iteration - 1] + AspirationDelta,  VALUE_INFINITE);
        }

        // Search to the current depth, rml is updated and sorted, alpha and beta could change
        value = root_search(p, ss, rml, &alpha, &beta);

        // Write PV to transposition table, in case the relevant entries have
        // been overwritten during the search.
        TT.insert_pv(p, ss[0].pv);

        if (AbortSearch)
            break; // Value cannot be trusted. Break out immediately!

        //Save info about search result
        ValueByIteration[Iteration] = value;

        // Drop the easy move if differs from the new best move
        if (ss[0].pv[0] != EasyMove)
            EasyMove = MOVE_NONE;

        if (UseTimeManagement)
        {
            // Time to stop?
            bool stopSearch = false;

            // Stop search early if there is only a single legal move,
            // we search up to Iteration 6 anyway to get a proper score.
            if (Iteration >= 6 && rml.move_count() == 1)
                stopSearch = true;

            // Stop search early when the last two iterations returned a mate score
            if (  Iteration >= 6
                && abs(ValueByIteration[Iteration]) >= abs(VALUE_MATE) - 100
                && abs(ValueByIteration[Iteration-1]) >= abs(VALUE_MATE) - 100)
                stopSearch = true;

            // Stop search early if one move seems to be much better than the others
            int64_t nodes = TM.nodes_searched();
            if (   Iteration >= 8
                && EasyMove == ss[0].pv[0]
                && (  (   rml.get_move_cumulative_nodes(0) > (nodes * 85) / 100
                       && current_search_time() > MaxSearchTime / 16)
                    ||(   rml.get_move_cumulative_nodes(0) > (nodes * 98) / 100
                       && current_search_time() > MaxSearchTime / 32)))
                stopSearch = true;

            // Add some extra time if the best move has changed during the last two iterations
            if (Iteration > 5 && Iteration <= 50)
                ExtraSearchTime = BestMoveChangesByIteration[Iteration]   * (MaxSearchTime / 2)
                                + BestMoveChangesByIteration[Iteration-1] * (MaxSearchTime / 3);

            // Stop search if most of MaxSearchTime is consumed at the end of the
            // iteration. We probably don't have enough time to search the first
            // move at the next iteration anyway.
            if (current_search_time() > ((MaxSearchTime + ExtraSearchTime) * 80) / 128)
                stopSearch = true;

            if (stopSearch)
            {
                if (PonderSearch)
                    StopOnPonderhit = true;
                else
                    break;
            }
        }

        if (MaxDepth && Iteration >= MaxDepth)
            break;
    }

    // If we are pondering or in infinite search, we shouldn't print the
    // best move before we are told to do so.
    if (!AbortSearch && (PonderSearch || InfiniteSearch))
        wait_for_stop_or_ponderhit();
    else
        // Print final search statistics
        cout << "info nodes " << TM.nodes_searched()
             << " nps " << nps()
             << " time " << current_search_time()
             << " hashfull " << TT.full() << endl;

    // Print the best move and the ponder move to the standard output
    if (ss[0].pv[0] == MOVE_NONE)
    {
        ss[0].pv[0] = rml.get_move(0);
        ss[0].pv[1] = MOVE_NONE;
    }

    assert(ss[0].pv[0] != MOVE_NONE);

    cout << "bestmove " << ss[0].pv[0];

    if (ss[0].pv[1] != MOVE_NONE)
        cout << " ponder " << ss[0].pv[1];

    cout << endl;

#if defined(IPHONE_GLAURUNG)
    bestmove_to_ui(move_to_string(ss[0].pv[0]), move_to_string(ss[0].pv[1]));
#endif

    if (UseLogFile)
    {
        if (dbg_show_mean)
            dbg_print_mean(LogFile);

        if (dbg_show_hit_rate)
            dbg_print_hit_rate(LogFile);

        LogFile << "\nNodes: " << TM.nodes_searched()
                << "\nNodes/second: " << nps()
                << "\nBest move: " << move_to_san(p, ss[0].pv[0]);

        StateInfo st;
        p.do_move(ss[0].pv[0], st);
        LogFile << "\nPonder move: "
                << move_to_san(p, ss[0].pv[1]) // Works also with MOVE_NONE
                << endl;
    }
    return rml.get_move_score(0);
  }


  // root_search() is the function which searches the root node. It is
  // similar to search_pv except that it uses a different move ordering
  // scheme, prints some information to the standard output and handles
  // the fail low/high loops.

  Value root_search(Position& pos, SearchStack ss[], RootMoveList& rml, Value* alphaPtr, Value* betaPtr) {

    EvalInfo ei;
    StateInfo st;
    CheckInfo ci(pos);
    int64_t nodes;
    Move move;
    Depth depth, ext, newDepth;
    Value value, alpha, beta;
    bool isCheck, moveIsCheck, captureOrPromotion, dangerous;
    int researchCountFH, researchCountFL;

    researchCountFH = researchCountFL = 0;
    alpha = *alphaPtr;
    beta = *betaPtr;
    isCheck = pos.is_check();

    // Step 1. Initialize node and poll (omitted at root, but I can see no good reason for this, FIXME)
    // Step 2. Check for aborted search (omitted at root, because we do not initialize root node)
    // Step 3. Mate distance pruning (omitted at root)
    // Step 4. Transposition table lookup (omitted at root)

    // Step 5. Evaluate the position statically
    // At root we do this only to get reference value for child nodes
    if (!isCheck)
        ss[0].eval = evaluate(pos, ei, 0);
    else
        ss[0].eval = VALUE_NONE; // HACK because we do not initialize root node

    // Step 6. Razoring (omitted at root)
    // Step 7. Static null move pruning (omitted at root)
    // Step 8. Null move search with verification search (omitted at root)
    // Step 9. Internal iterative deepening (omitted at root)

    // Step extra. Fail low loop
    // We start with small aspiration window and in case of fail low, we research
    // with bigger window until we are not failing low anymore.
    while (1)
    {
        // Sort the moves before to (re)search
        rml.sort();

        // Step 10. Loop through all moves in the root move list
        for (int i = 0; i <  rml.move_count() && !AbortSearch; i++)
        {
            // This is used by time management
            FirstRootMove = (i == 0);

            // Save the current node count before the move is searched
            nodes = TM.nodes_searched();

            // Reset beta cut-off counters
            TM.resetBetaCounters();

            // Pick the next root move, and print the move and the move number to
            // the standard output.
            move = ss[0].currentMove = rml.get_move(i);

            if (current_search_time() >= 1000) {
                cout << "info currmove " << move
                     << " currmovenumber " << i + 1 << endl;
#if defined(IPHONE_GLAURUNG)
                currmove_to_ui(move_to_san(pos, move), i+1, rml.move_count());
#endif
            }

            moveIsCheck = pos.move_is_check(move);
            captureOrPromotion = pos.move_is_capture_or_promotion(move);

            // Step 11. Decide the new search depth
            depth = (Iteration - 2) * OnePly + InitialDepth;
            ext = extension(pos, move, true, captureOrPromotion, moveIsCheck, false, false, &dangerous);
            newDepth = depth + ext;

            // Step 12. Futility pruning (omitted at root)

            // Step extra. Fail high loop
            // If move fails high, we research with bigger window until we are not failing
            // high anymore.
            value = - VALUE_INFINITE;

            while (1)
            {
                // Step 13. Make the move
                pos.do_move(move, st, ci, moveIsCheck);

                // Step extra. pv search
                // We do pv search for first moves (i < MultiPV)
                // and for fail high research (value > alpha)
                if (i < MultiPV || value > alpha)
                {
                    // Aspiration window is disabled in multi-pv case
                    if (MultiPV > 1)
                        alpha = -VALUE_INFINITE;

                    // Full depth PV search, done on first move or after a fail high
                    value = -search_pv(pos, ss, -beta, -alpha, newDepth, 1, 0);
                }
                else
                {
                    // Step 14. Reduced search
                    // if the move fails high will be re-searched at full depth
                    bool doFullDepthSearch = true;

                    if (    depth >= 3 * OnePly
                        && !dangerous
                        && !captureOrPromotion
                        && !move_is_castle(move))
                    {
                        ss[0].reduction = pv_reduction(depth, i - MultiPV + 2);
                        if (ss[0].reduction)
                        {
                            // Reduced depth non-pv search using alpha as upperbound
                            value = -search(pos, ss, -alpha, newDepth-ss[0].reduction, 1, true, 0);
                            doFullDepthSearch = (value > alpha);
                        }
                    }

                    // Step 15. Full depth search
                    if (doFullDepthSearch)
                    {
                        // Full depth non-pv search using alpha as upperbound
                        ss[0].reduction = Depth(0);
                        value = -search(pos, ss, -alpha, newDepth, 1, true, 0);

                        // If we are above alpha then research at same depth but as PV
                        // to get a correct score or eventually a fail high above beta.
                        if (value > alpha)
                            value = -search_pv(pos, ss, -beta, -alpha, newDepth, 1, 0);
                    }
                }

                // Step 16. Undo move
                pos.undo_move(move);

                // Can we exit fail high loop ?
                if (AbortSearch || value < beta)
                    break;

                // We are failing high and going to do a research. It's important to update
                // the score before research in case we run out of time while researching.
                rml.set_move_score(i, value);
                update_pv(ss, 0);
                TT.extract_pv(pos, ss[0].pv, PLY_MAX);
                rml.set_move_pv(i, ss[0].pv);

                // Print information to the standard output
                print_pv_info(pos, ss, alpha, beta, value);

                // Prepare for a research after a fail high, each time with a wider window
                *betaPtr = beta = Min(beta + AspirationDelta * (1 << researchCountFH), VALUE_INFINITE);
                researchCountFH++;

            } // End of fail high loop

            // Finished searching the move. If AbortSearch is true, the search
            // was aborted because the user interrupted the search or because we
            // ran out of time. In this case, the return value of the search cannot
            // be trusted, and we break out of the loop without updating the best
            // move and/or PV.
            if (AbortSearch)
                break;

            // Remember beta-cutoff and searched nodes counts for this move. The
            // info is used to sort the root moves for the next iteration.
            int64_t our, their;
            TM.get_beta_counters(pos.side_to_move(), our, their);
            rml.set_beta_counters(i, our, their);
            rml.set_move_nodes(i, TM.nodes_searched() - nodes);

            assert(value >= -VALUE_INFINITE && value <= VALUE_INFINITE);
            assert(value < beta);

            // Step 17. Check for new best move
            if (value <= alpha && i >= MultiPV)
                rml.set_move_score(i, -VALUE_INFINITE);
            else
            {
                // PV move or new best move!

                // In handicap mode, decide whether we should blunder and miss
                // this move.
                int blunder = (Blunder && i > 0 && !pos.is_check())?
                  blunder_modulus(pos, move, newDepth) : 0;
                if (blunder && pos.get_key() % blunder == 0)
                    continue;

                // Update PV
                rml.set_move_score(i, value);
                update_pv(ss, 0);
                TT.extract_pv(pos, ss[0].pv, PLY_MAX);
                rml.set_move_pv(i, ss[0].pv);

                if (MultiPV == 1)
                {
                    // We record how often the best move has been changed in each
                    // iteration. This information is used for time managment: When
                    // the best move changes frequently, we allocate some more time.
                    if (i > 0)
                        BestMoveChangesByIteration[Iteration]++;

                    // Print information to the standard output
                    print_pv_info(pos, ss, alpha, beta, value);

                    // Raise alpha to setup proper non-pv search upper bound
                    if (value > alpha)
                        alpha = value;
                }
                else // MultiPV > 1
                {
                    rml.sort_multipv(i);
                    for (int j = 0; j < Min(MultiPV, rml.move_count()); j++)
                    {
                        cout << "info multipv " << j + 1
                             << " score " << value_to_string(rml.get_move_score(j))
                             << " depth " << (j <= i ? Iteration : Iteration - 1)
                             << " time " << current_search_time()
                             << " nodes " << TM.nodes_searched()
                             << " nps " << nps()
                             << " pv ";

                        for (int k = 0; rml.get_move_pv(j, k) != MOVE_NONE && k < PLY_MAX; k++)
                            cout << rml.get_move_pv(j, k) << " ";

                        cout << endl;
                    }
                    alpha = rml.get_move_score(Min(i, MultiPV - 1));
                }
            } // PV move or new best move

            assert(alpha >= *alphaPtr);

            AspirationFailLow = (alpha == *alphaPtr);

            if (AspirationFailLow && StopOnPonderhit)
                StopOnPonderhit = false;
        }

        // Can we exit fail low loop ?
        if (AbortSearch || !AspirationFailLow)
            break;

        // Prepare for a research after a fail low, each time with a wider window
        *alphaPtr = alpha = Max(alpha - AspirationDelta * (1 << researchCountFL), -VALUE_INFINITE);
        researchCountFL++;

    } // Fail low loop

    // Sort the moves before to return
    rml.sort();

    return alpha;
  }


  // search_pv() is the main search function for PV nodes.

  Value search_pv(Position& pos, SearchStack ss[], Value alpha, Value beta,
                  Depth depth, int ply, int threadID) {

    assert(alpha >= -VALUE_INFINITE && alpha <= VALUE_INFINITE);
    assert(beta > alpha && beta <= VALUE_INFINITE);
    assert(ply >= 0 && ply < PLY_MAX);
    assert(threadID >= 0 && threadID < TM.active_threads());

    Move movesSearched[256];
    EvalInfo ei;
    StateInfo st;
    const TTEntry* tte;
    Move ttMove, move;
    Depth ext, newDepth;
    Value bestValue, value, oldAlpha;
    bool isCheck, singleEvasion, moveIsCheck, captureOrPromotion, dangerous;
    bool mateThreat = false;
    int moveCount = 0;
    bestValue = value = -VALUE_INFINITE;

    if (depth < OnePly)
        return qsearch(pos, ss, alpha, beta, Depth(0), ply, threadID);

    // Step 1. Initialize node and poll
    // Polling can abort search.
    init_node(pos, ss, ply, threadID);

    // Step 2. Check for aborted search and immediate draw
    if (AbortSearch || TM.thread_should_stop(threadID))
        return Value(0);

    if (pos.is_draw() || ply >= PLY_MAX - 1)
        return VALUE_DRAW;

    // Step 3. Mate distance pruning
    oldAlpha = alpha;
    alpha = Max(value_mated_in(ply), alpha);
    beta = Min(value_mate_in(ply+1), beta);
    if (alpha >= beta)
        return alpha;

    // Step 4. Transposition table lookup
    // At PV nodes, we don't use the TT for pruning, but only for move ordering.
    // This is to avoid problems in the following areas:
    //
    // * Repetition draw detection
    // * Fifty move rule detection
    // * Searching for a mate
    // * Printing of full PV line
    tte = TT.retrieve(pos.get_key());
    ttMove = (tte ? tte->move() : MOVE_NONE);

    // Step 5. Evaluate the position statically
    // At PV nodes we do this only to update gain statistics
    isCheck = pos.is_check();
    if (!isCheck)
    {
        ss[ply].eval = evaluate(pos, ei, threadID);
        update_gains(pos, ss[ply - 1].currentMove, ss[ply - 1].eval, ss[ply].eval);
    }

    // Step 6. Razoring (is omitted in PV nodes)
    // Step 7. Static null move pruning (is omitted in PV nodes)
    // Step 8. Null move search with verification search (is omitted in PV nodes)

    // Step 9. Internal iterative deepening
    if (   depth >= IIDDepthAtPVNodes
        && ttMove == MOVE_NONE)
    {
        search_pv(pos, ss, alpha, beta, depth-2*OnePly, ply, threadID);
        ttMove = ss[ply].pv[ply];
        tte = TT.retrieve(pos.get_key());
    }

    // Initialize a MovePicker object for the current position
    mateThreat = pos.has_mate_threat(opposite_color(pos.side_to_move()));
    MovePicker mp = MovePicker(pos, ttMove, depth, H, &ss[ply]);
    CheckInfo ci(pos);

    // Step 10. Loop through moves
    // Loop through all legal moves until no moves remain or a beta cutoff occurs
    while (   alpha < beta
           && (move = mp.get_next_move()) != MOVE_NONE
           && !TM.thread_should_stop(threadID))
    {
      assert(move_is_ok(move));

      singleEvasion = (isCheck && mp.number_of_evasions() == 1);
      moveIsCheck = pos.move_is_check(move, ci);
      captureOrPromotion = pos.move_is_capture_or_promotion(move);

      // Step 11. Decide the new search depth
      ext = extension(pos, move, true, captureOrPromotion, moveIsCheck, singleEvasion, mateThreat, &dangerous);

      // Singular extension search. We extend the TT move if its value is much better than
      // its siblings. To verify this we do a reduced search on all the other moves but the
      // ttMove, if result is lower then ttValue minus a margin then we extend ttMove.
      if (   depth >= SingularExtensionDepthAtPVNodes
          && tte
          && move == tte->move()
          && ext < OnePly
          && is_lower_bound(tte->type())
          && tte->depth() >= depth - 3 * OnePly)
      {
          Value ttValue = value_from_tt(tte->value(), ply);

          if (abs(ttValue) < VALUE_KNOWN_WIN)
          {
              Value excValue = search(pos, ss, ttValue - SingularExtensionMargin, depth / 2, ply, false, threadID, move);

              if (excValue < ttValue - SingularExtensionMargin)
                  ext = OnePly;
          }
      }

      newDepth = depth - OnePly + ext;

      // Update current move (this must be done after singular extension search)
      movesSearched[moveCount++] = ss[ply].currentMove = move;

      // Step 12. Futility pruning (is omitted in PV nodes)

      // Step 13. Make the move
      pos.do_move(move, st, ci, moveIsCheck);

      // Step extra. pv search (only in PV nodes)
      // The first move in list is the expected PV
      if (moveCount == 1)
          value = -search_pv(pos, ss, -beta, -alpha, newDepth, ply+1, threadID);
      else
      {
        // Step 14. Reduced search
        // if the move fails high will be re-searched at full depth.
        bool doFullDepthSearch = true;

        if (    depth >= 3 * OnePly
            && !dangerous
            && !captureOrPromotion
            && !move_is_castle(move)
            && !move_is_killer(move, ss[ply]))
        {
            ss[ply].reduction = pv_reduction(depth, moveCount);
            if (ss[ply].reduction)
            {
                value = -search(pos, ss, -alpha, newDepth-ss[ply].reduction, ply+1, true, threadID);
                doFullDepthSearch = (value > alpha);
            }
        }

        // Step 15. Full depth search
        if (doFullDepthSearch)
        {
            ss[ply].reduction = Depth(0);
            value = -search(pos, ss, -alpha, newDepth, ply+1, true, threadID);

            // Step extra. pv search (only in PV nodes)
            if (value > alpha && value < beta)
                value = -search_pv(pos, ss, -beta, -alpha, newDepth, ply+1, threadID);
        }
      }

      // Step 16. Undo move
      pos.undo_move(move);

      assert(value > -VALUE_INFINITE && value < VALUE_INFINITE);

      // Step 17. Check for new best move
      if (value > bestValue)
      {
          // If in handicap mode, decide whether we should blunder and miss
          // this move.
          int blunder = (Blunder && moveCount > 1 && !pos.is_check()
                         && bestValue >= value_mated_in(3))?
            blunder_modulus(pos, move, newDepth) : 0;
          if (blunder && pos.get_key() % blunder == 0)
              continue;
          
          bestValue = value;
          if (value > alpha)
          {
              alpha = value;
              update_pv(ss, ply);
              if (value == value_mate_in(ply + 1))
                  ss[ply].mateKiller = move;
          }
      }

      // Step 18. Check for split
      if (   TM.active_threads() > 1
          && bestValue < beta
          && depth >= MinimumSplitDepth
          && Iteration <= 99
          && TM.available_thread_exists(threadID)
          && !AbortSearch
          && !TM.thread_should_stop(threadID)
          && TM.split(pos, ss, ply, &alpha, beta, &bestValue,
                      depth, mateThreat, &moveCount, &mp, threadID, true))
          break;
    }

    // Step 19. Check for mate and stalemate
    // All legal moves have been searched and if there were
    // no legal moves, it must be mate or stalemate.
    if (moveCount == 0)
        return (isCheck ? value_mated_in(ply) : VALUE_DRAW);

    // Step 20. Update tables
    // If the search is not aborted, update the transposition table,
    // history counters, and killer moves.
    if (AbortSearch || TM.thread_should_stop(threadID))
        return bestValue;

    if (bestValue <= oldAlpha)
        TT.store(pos.get_key(), value_to_tt(bestValue, ply), VALUE_TYPE_UPPER, depth, MOVE_NONE);

    else if (bestValue >= beta)
    {
        TM.incrementBetaCounter(pos.side_to_move(), depth, threadID);
        move = ss[ply].pv[ply];
        if (!pos.move_is_capture_or_promotion(move))
        {
            update_history(pos, move, depth, movesSearched, moveCount);
            update_killers(move, ss[ply]);
        }
        TT.store(pos.get_key(), value_to_tt(bestValue, ply), VALUE_TYPE_LOWER, depth, move);
    }
    else
        TT.store(pos.get_key(), value_to_tt(bestValue, ply), VALUE_TYPE_EXACT, depth, ss[ply].pv[ply]);

    return bestValue;
  }


  // search() is the search function for zero-width nodes.

  Value search(Position& pos, SearchStack ss[], Value beta, Depth depth,
               int ply, bool allowNullmove, int threadID, Move excludedMove) {

    assert(beta >= -VALUE_INFINITE && beta <= VALUE_INFINITE);
    assert(ply >= 0 && ply < PLY_MAX);
    assert(threadID >= 0 && threadID < TM.active_threads());

    Move movesSearched[256];
    EvalInfo ei;
    StateInfo st;
    const TTEntry* tte;
    Move ttMove, move;
    Depth ext, newDepth;
    Value bestValue, refinedValue, nullValue, value, futilityValueScaled;
    bool isCheck, singleEvasion, moveIsCheck, captureOrPromotion, dangerous;
    bool mateThreat = false;
    int moveCount = 0;
    refinedValue = bestValue = value = -VALUE_INFINITE;

    if (depth < OnePly)
        return qsearch(pos, ss, beta-1, beta, Depth(0), ply, threadID);

    // Step 1. Initialize node and poll
    // Polling can abort search.
    init_node(pos, ss, ply, threadID);

    // Step 2. Check for aborted search and immediate draw
    if (AbortSearch || TM.thread_should_stop(threadID))
        return Value(0);

    if (pos.is_draw() || ply >= PLY_MAX - 1)
        return VALUE_DRAW;

    // Step 3. Mate distance pruning
    if (value_mated_in(ply) >= beta)
        return beta;

    if (value_mate_in(ply + 1) < beta)
        return beta - 1;

    // Step 4. Transposition table lookup

    // We don't want the score of a partial search to overwrite a previous full search
    // TT value, so we use a different position key in case of an excluded move exists.
    Key posKey = excludedMove ? pos.get_exclusion_key() : pos.get_key();

    tte = TT.retrieve(posKey);
    ttMove = (tte ? tte->move() : MOVE_NONE);

    if (tte && ok_to_use_TT(tte, depth, beta, ply, allowNullmove))
    {
        ss[ply].currentMove = ttMove; // Can be MOVE_NONE
        return value_from_tt(tte->value(), ply);
    }

    // Step 5. Evaluate the position statically
    isCheck = pos.is_check();

    if (!isCheck)
    {
        if (tte && (tte->type() & VALUE_TYPE_EVAL))
            ss[ply].eval = value_from_tt(tte->value(), ply);
        else
            ss[ply].eval = evaluate(pos, ei, threadID);

        refinedValue = refine_eval(tte, ss[ply].eval, ply); // Enhance accuracy with TT value if possible
        update_gains(pos, ss[ply - 1].currentMove, ss[ply - 1].eval, ss[ply].eval);
    }

    // Step 6. Razoring
    if (    refinedValue < beta - razor_margin(depth)
        &&  ttMove == MOVE_NONE
        &&  ss[ply - 1].currentMove != MOVE_NULL
        &&  depth < RazorDepth
        && !isCheck
        && !value_is_mate(beta)
        && !pos.has_pawn_on_7th(pos.side_to_move()))
    {
        Value rbeta = beta - razor_margin(depth);
        Value v = qsearch(pos, ss, rbeta-1, rbeta, Depth(0), ply, threadID);
        if (v < rbeta)
            // Logically we should return (v + razor_margin(depth)), but
            // surprisingly this did slightly weaker in tests.
            return v;
    }

    // Step 7. Static null move pruning
    // We're betting that the opponent doesn't have a move that will reduce
    // the score by more than futility_margin(depth) if we do a null move.
    if (    allowNullmove
        &&  depth < RazorDepth
        && !isCheck
        && !value_is_mate(beta)
        &&  ok_to_do_nullmove(pos)
        &&  refinedValue >= beta + futility_margin(depth, 0))
        return refinedValue - futility_margin(depth, 0);

    // Step 8. Null move search with verification search
    // When we jump directly to qsearch() we do a null move only if static value is
    // at least beta. Otherwise we do a null move if static value is not more than
    // NullMoveMargin under beta.
    if (    allowNullmove
        &&  depth > OnePly
        && !isCheck
        && !value_is_mate(beta)
        &&  ok_to_do_nullmove(pos)
        &&  refinedValue >= beta - (depth >= 4 * OnePly ? NullMoveMargin : 0))
    {
        ss[ply].currentMove = MOVE_NULL;

        // Null move dynamic reduction based on depth
        int R = 3 + (depth >= 5 * OnePly ? depth / 8 : 0);

        // Null move dynamic reduction based on value
        if (refinedValue - beta > PawnValueMidgame)
            R++;

        pos.do_null_move(st);

        nullValue = -search(pos, ss, -(beta-1), depth-R*OnePly, ply+1, false, threadID);

        pos.undo_null_move();

        if (nullValue >= beta)
        {
            // Do not return unproven mate scores
            if (nullValue >= value_mate_in(PLY_MAX))
                nullValue = beta;

            // Do zugzwang verification search for high depths, don't store in TT
            // if search was stopped.
            if (   (   depth < 6 * OnePly
                    || search(pos, ss, beta, depth-5*OnePly, ply, false, threadID) >= beta)
                && !AbortSearch
                && !TM.thread_should_stop(threadID))
            {
                assert(value_to_tt(nullValue, ply) == nullValue);

                TT.store(posKey, nullValue, VALUE_TYPE_NS_LO, depth, MOVE_NONE);
                return nullValue;
            }
        } else {
            // The null move failed low, which means that we may be faced with
            // some kind of threat. If the previous move was reduced, check if
            // the move that refuted the null move was somehow connected to the
            // move which was reduced. If a connection is found, return a fail
            // low score (which will cause the reduced move to fail high in the
            // parent node, which will trigger a re-search with full depth).
            if (nullValue == value_mated_in(ply + 2))
                mateThreat = true;

            ss[ply].threatMove = ss[ply + 1].currentMove;
            if (   depth < ThreatDepth
                && ss[ply - 1].reduction
                && connected_moves(pos, ss[ply - 1].currentMove, ss[ply].threatMove))
                return beta - 1;
        }
    }

    // Step 9. Internal iterative deepening
    if (   depth >= IIDDepthAtNonPVNodes
        && ttMove == MOVE_NONE
        && !isCheck
        && ss[ply].eval >= beta - IIDMargin)
    {
        search(pos, ss, beta, depth/2, ply, false, threadID);
        ttMove = ss[ply].pv[ply];
        tte = TT.retrieve(posKey);
    }

    // Initialize a MovePicker object for the current position
    MovePicker mp = MovePicker(pos, ttMove, depth, H, &ss[ply], beta);
    CheckInfo ci(pos);

    // Step 10. Loop through moves
    // Loop through all legal moves until no moves remain or a beta cutoff occurs
    while (   bestValue < beta
           && (move = mp.get_next_move()) != MOVE_NONE
           && !TM.thread_should_stop(threadID))
    {
      assert(move_is_ok(move));

      if (move == excludedMove)
          continue;

      moveIsCheck = pos.move_is_check(move, ci);
      singleEvasion = (isCheck && mp.number_of_evasions() == 1);
      captureOrPromotion = pos.move_is_capture_or_promotion(move);

      // Step 11. Decide the new search depth
      ext = extension(pos, move, false, captureOrPromotion, moveIsCheck, singleEvasion, mateThreat, &dangerous);

      // Singular extension search. We extend the TT move if its value is much better than
      // its siblings. To verify this we do a reduced search on all the other moves but the
      // ttMove, if result is lower then ttValue minus a margin then we extend ttMove.
      if (   depth >= SingularExtensionDepthAtNonPVNodes
          && tte
          && move == tte->move()
          && !excludedMove // Do not allow recursive singular extension search
          && ext < OnePly
          && is_lower_bound(tte->type())
          && tte->depth() >= depth - 3 * OnePly)
      {
          Value ttValue = value_from_tt(tte->value(), ply);

          if (abs(ttValue) < VALUE_KNOWN_WIN)
          {
              Value excValue = search(pos, ss, ttValue - SingularExtensionMargin, depth / 2, ply, false, threadID, move);

              if (excValue < ttValue - SingularExtensionMargin)
                  ext = OnePly;
          }
      }

      newDepth = depth - OnePly + ext;

      // Update current move (this must be done after singular extension search)
      movesSearched[moveCount++] = ss[ply].currentMove = move;

      // Step 12. Futility pruning
      if (   !isCheck
          && !dangerous
          && !captureOrPromotion
          && !move_is_castle(move)
          &&  move != ttMove)
      {
          // Move count based pruning
          if (   moveCount >= futility_move_count(depth)
              && ok_to_prune(pos, move, ss[ply].threatMove)
              && bestValue > value_mated_in(PLY_MAX))
              continue;

          // Value based pruning
          Depth predictedDepth = newDepth - nonpv_reduction(depth, moveCount); // We illogically ignore reduction condition depth >= 3*OnePly
          futilityValueScaled =  ss[ply].eval + futility_margin(predictedDepth, moveCount)
                               + H.gain(pos.piece_on(move_from(move)), move_to(move)) + 45;

          if (futilityValueScaled < beta)
          {
              if (futilityValueScaled > bestValue)
                  bestValue = futilityValueScaled;
              continue;
          }
      }

      // Step 13. Make the move
      pos.do_move(move, st, ci, moveIsCheck);

      // Step 14. Reduced search, if the move fails high
      // will be re-searched at full depth.
      bool doFullDepthSearch = true;

      if (    depth >= 3*OnePly
          && !dangerous
          && !captureOrPromotion
          && !move_is_castle(move)
          && !move_is_killer(move, ss[ply]))
      {
          ss[ply].reduction = nonpv_reduction(depth, moveCount);
          if (ss[ply].reduction)
          {
              value = -search(pos, ss, -(beta-1), newDepth-ss[ply].reduction, ply+1, true, threadID);
              doFullDepthSearch = (value >= beta);
          }
      }

      // Step 15. Full depth search
      if (doFullDepthSearch)
      {
          ss[ply].reduction = Depth(0);
          value = -search(pos, ss, -(beta-1), newDepth, ply+1, true, threadID);
      }

      // Step 16. Undo move
      pos.undo_move(move);

      assert(value > -VALUE_INFINITE && value < VALUE_INFINITE);

      // Step 17. Check for new best move
      if (value > bestValue)
      {
          // If in handicap mode, decide whether we should blunder and miss
          // this move.

          int blunder = (Blunder && moveCount > 1 && !pos.is_check()
                         && bestValue >= value_mated_in(3))?
            blunder_modulus(pos, move, newDepth) : 0;
          if (blunder && pos.get_key() % blunder == 0)
              continue;
        
          bestValue = value;
          if (value >= beta)
              update_pv(ss, ply);

          if (value == value_mate_in(ply + 1))
              ss[ply].mateKiller = move;
      }

      // Step 18. Check for split
      if (   TM.active_threads() > 1
          && bestValue < beta
          && depth >= MinimumSplitDepth
          && Iteration <= 99
          && TM.available_thread_exists(threadID)
          && !AbortSearch
          && !TM.thread_should_stop(threadID)
          && TM.split(pos, ss, ply, NULL, beta, &bestValue,
                      depth, mateThreat, &moveCount, &mp, threadID, false))
          break;
    }

    // Step 19. Check for mate and stalemate
    // All legal moves have been searched and if there are
    // no legal moves, it must be mate or stalemate.
    // If one move was excluded return fail low score.
    if (!moveCount)
        return excludedMove ? beta - 1 : (isCheck ? value_mated_in(ply) : VALUE_DRAW);

    // Step 20. Update tables
    // If the search is not aborted, update the transposition table,
    // history counters, and killer moves.
    if (AbortSearch || TM.thread_should_stop(threadID))
        return bestValue;

    if (bestValue < beta)
        TT.store(posKey, value_to_tt(bestValue, ply), VALUE_TYPE_UPPER, depth, MOVE_NONE);
    else
    {
        TM.incrementBetaCounter(pos.side_to_move(), depth, threadID);
        move = ss[ply].pv[ply];
        TT.store(posKey, value_to_tt(bestValue, ply), VALUE_TYPE_LOWER, depth, move);
        if (!pos.move_is_capture_or_promotion(move))
        {
            update_history(pos, move, depth, movesSearched, moveCount);
            update_killers(move, ss[ply]);
        }

    }

    assert(bestValue > -VALUE_INFINITE && bestValue < VALUE_INFINITE);

    return bestValue;
  }


  // qsearch() is the quiescence search function, which is called by the main
  // search function when the remaining depth is zero (or, to be more precise,
  // less than OnePly).

  Value qsearch(Position& pos, SearchStack ss[], Value alpha, Value beta,
                Depth depth, int ply, int threadID) {

    assert(alpha >= -VALUE_INFINITE && alpha <= VALUE_INFINITE);
    assert(beta >= -VALUE_INFINITE && beta <= VALUE_INFINITE);
    assert(depth <= 0);
    assert(ply >= 0 && ply < PLY_MAX);
    assert(threadID >= 0 && threadID < TM.active_threads());

    EvalInfo ei;
    StateInfo st;
    Move ttMove, move;
    Value staticValue, bestValue, value, futilityBase, futilityValue;
    bool isCheck, enoughMaterial, moveIsCheck, evasionPrunable;
    const TTEntry* tte = NULL;
    int moveCount = 0;
    bool pvNode = (beta - alpha != 1);
    Value oldAlpha = alpha;

    // Initialize, and make an early exit in case of an aborted search,
    // an instant draw, maximum ply reached, etc.
    init_node(pos, ss, ply, threadID);

    // After init_node() that calls poll()
    if (AbortSearch || TM.thread_should_stop(threadID))
        return Value(0);

    if (pos.is_draw() || ply >= PLY_MAX - 1)
        return VALUE_DRAW;

    // Transposition table lookup. At PV nodes, we don't use the TT for
    // pruning, but only for move ordering.
    tte = TT.retrieve(pos.get_key());
    ttMove = (tte ? tte->move() : MOVE_NONE);

    if (!pvNode && tte && ok_to_use_TT(tte, depth, beta, ply, true))
    {
        assert(tte->type() != VALUE_TYPE_EVAL);

        ss[ply].currentMove = ttMove; // Can be MOVE_NONE
        return value_from_tt(tte->value(), ply);
    }

    isCheck = pos.is_check();

    // Evaluate the position statically
    if (isCheck)
        staticValue = -VALUE_INFINITE;
    else if (tte && (tte->type() & VALUE_TYPE_EVAL))
        staticValue = value_from_tt(tte->value(), ply);
    else
        staticValue = evaluate(pos, ei, threadID);

    if (!isCheck)
    {
        ss[ply].eval = staticValue;
        update_gains(pos, ss[ply - 1].currentMove, ss[ply - 1].eval, ss[ply].eval);
    }

    // Initialize "stand pat score", and return it immediately if it is
    // at least beta.
    bestValue = staticValue;

    if (bestValue >= beta)
    {
        // Store the score to avoid a future costly evaluation() call
        if (!isCheck && !tte && ei.futilityMargin[pos.side_to_move()] == 0)
            TT.store(pos.get_key(), value_to_tt(bestValue, ply), VALUE_TYPE_EV_LO, Depth(-127*OnePly), MOVE_NONE);

        return bestValue;
    }

    if (bestValue > alpha)
        alpha = bestValue;

    // If we are near beta then try to get a cutoff pushing checks a bit further
    bool deepChecks = (depth == -OnePly && staticValue >= beta - PawnValueMidgame / 8);

    // Initialize a MovePicker object for the current position, and prepare
    // to search the moves. Because the depth is <= 0 here, only captures,
    // queen promotions and checks (only if depth == 0 or depth == -OnePly
    // and we are near beta) will be generated.
    MovePicker mp = MovePicker(pos, ttMove, deepChecks ? Depth(0) : depth, H);
    CheckInfo ci(pos);
    enoughMaterial = pos.non_pawn_material(pos.side_to_move()) > RookValueMidgame;
    futilityBase = staticValue + FutilityMarginQS + ei.futilityMargin[pos.side_to_move()];

    // Loop through the moves until no moves remain or a beta cutoff occurs
    while (   alpha < beta
           && (move = mp.get_next_move()) != MOVE_NONE)
    {
      assert(move_is_ok(move));

      moveIsCheck = pos.move_is_check(move, ci);

      // Update current move
      moveCount++;
      ss[ply].currentMove = move;

      // Futility pruning
      if (   enoughMaterial
          && !isCheck
          && !pvNode
          && !moveIsCheck
          &&  move != ttMove
          && !move_is_promotion(move)
          && !pos.move_is_passed_pawn_push(move))
      {
          futilityValue =  futilityBase
                         + pos.endgame_value_of_piece_on(move_to(move))
                         + (move_is_ep(move) ? PawnValueEndgame : Value(0));

          if (futilityValue < alpha)
          {
              if (futilityValue > bestValue)
                  bestValue = futilityValue;
              continue;
          }
      }

      // Detect blocking evasions that are candidate to be pruned
      evasionPrunable =   isCheck
                       && bestValue != -VALUE_INFINITE
                       && !pos.move_is_capture(move)
                       && pos.type_of_piece_on(move_from(move)) != KING
                       && !pos.can_castle(pos.side_to_move());

      // Don't search moves with negative SEE values
      if (   (!isCheck || evasionPrunable)
          && !pvNode
          &&  move != ttMove
          && !move_is_promotion(move)
          &&  pos.see_sign(move) < 0)
          continue;

      // Make and search the move
      pos.do_move(move, st, ci, moveIsCheck);
      value = -qsearch(pos, ss, -beta, -alpha, depth-OnePly, ply+1, threadID);
      pos.undo_move(move);

      assert(value > -VALUE_INFINITE && value < VALUE_INFINITE);

      // New best move?
      if (value > bestValue)
      {
          // If in handicap mode, decide whether we should blunder and miss
          // this move.
          int blunder = (Blunder && moveCount > 1 && !pos.is_check()
                         && bestValue >= value_mated_in(3))?
            blunder_modulus(pos, move, Depth(1)) : 0;
          if (blunder && pos.get_key() % blunder == 0)
              continue;
        
          bestValue = value;
          if (value > alpha)
          {
              alpha = value;
              update_pv(ss, ply);
          }
       }
    }

    // All legal moves have been searched. A special case: If we're in check
    // and no legal moves were found, it is checkmate.
    if (!moveCount && isCheck) // Mate!
        return value_mated_in(ply);

    // Update transposition table
    Depth d = (depth == Depth(0) ? Depth(0) : Depth(-1));
    if (bestValue <= oldAlpha)
    {
        // If bestValue isn't changed it means it is still the static evaluation
        // of the node, so keep this info to avoid a future evaluation() call.
        ValueType type = (bestValue == staticValue && !ei.futilityMargin[pos.side_to_move()] ? VALUE_TYPE_EV_UP : VALUE_TYPE_UPPER);
        TT.store(pos.get_key(), value_to_tt(bestValue, ply), type, d, MOVE_NONE);
    }
    else if (bestValue >= beta)
    {
        move = ss[ply].pv[ply];
        TT.store(pos.get_key(), value_to_tt(bestValue, ply), VALUE_TYPE_LOWER, d, move);

        // Update killers only for good checking moves
        if (!pos.move_is_capture_or_promotion(move))
            update_killers(move, ss[ply]);
    }
    else
        TT.store(pos.get_key(), value_to_tt(bestValue, ply), VALUE_TYPE_EXACT, d, ss[ply].pv[ply]);

    assert(bestValue > -VALUE_INFINITE && bestValue < VALUE_INFINITE);

    return bestValue;
  }


  // sp_search() is used to search from a split point.  This function is called
  // by each thread working at the split point.  It is similar to the normal
  // search() function, but simpler.  Because we have already probed the hash
  // table, done a null move search, and searched the first move before
  // splitting, we don't have to repeat all this work in sp_search().  We
  // also don't need to store anything to the hash table here:  This is taken
  // care of after we return from the split point.

  void sp_search(SplitPoint* sp, int threadID) {

    assert(threadID >= 0 && threadID < TM.active_threads());
    assert(TM.active_threads() > 1);

    StateInfo st;
    Move move;
    Depth ext, newDepth;
    Value value, futilityValueScaled;
    bool isCheck, moveIsCheck, captureOrPromotion, dangerous;
    int moveCount;
    value = -VALUE_INFINITE;

    Position pos(*sp->pos);
    CheckInfo ci(pos);
    SearchStack* ss = sp->sstack[threadID];
    isCheck = pos.is_check();

    // Step 10. Loop through moves
    // Loop through all legal moves until no moves remain or a beta cutoff occurs
    lock_grab(&(sp->lock));

    while (    sp->bestValue < sp->beta
           && !TM.thread_should_stop(threadID)
           && (move = sp->mp->get_next_move()) != MOVE_NONE)
    {
      moveCount = ++sp->moves;
      lock_release(&(sp->lock));

      assert(move_is_ok(move));

      moveIsCheck = pos.move_is_check(move, ci);
      captureOrPromotion = pos.move_is_capture_or_promotion(move);

      // Step 11. Decide the new search depth
      ext = extension(pos, move, false, captureOrPromotion, moveIsCheck, false, sp->mateThreat, &dangerous);
      newDepth = sp->depth - OnePly + ext;

      // Update current move
      ss[sp->ply].currentMove = move;

      // Step 12. Futility pruning
      if (   !isCheck
          && !dangerous
          && !captureOrPromotion
          && !move_is_castle(move))
      {
          // Move count based pruning
          if (   moveCount >= futility_move_count(sp->depth)
              && ok_to_prune(pos, move, ss[sp->ply].threatMove)
              && sp->bestValue > value_mated_in(PLY_MAX))
          {
              lock_grab(&(sp->lock));
              continue;
          }

          // Value based pruning
          Depth predictedDepth = newDepth - nonpv_reduction(sp->depth, moveCount);
          futilityValueScaled =  ss[sp->ply].eval + futility_margin(predictedDepth, moveCount)
                                     + H.gain(pos.piece_on(move_from(move)), move_to(move)) + 45;

          if (futilityValueScaled < sp->beta)
          {
              lock_grab(&(sp->lock));

              if (futilityValueScaled > sp->bestValue)
                  sp->bestValue = futilityValueScaled;
              continue;
          }
      }

      // Step 13. Make the move
      pos.do_move(move, st, ci, moveIsCheck);

      // Step 14. Reduced search
      // if the move fails high will be re-searched at full depth.
      bool doFullDepthSearch = true;

      if (   !dangerous
          && !captureOrPromotion
          && !move_is_castle(move)
          && !move_is_killer(move, ss[sp->ply]))
      {
          ss[sp->ply].reduction = nonpv_reduction(sp->depth, moveCount);
          if (ss[sp->ply].reduction)
          {
              value = -search(pos, ss, -(sp->beta-1), newDepth-ss[sp->ply].reduction, sp->ply+1, true, threadID);
              doFullDepthSearch = (value >= sp->beta && !TM.thread_should_stop(threadID));
          }
      }

      // Step 15. Full depth search
      if (doFullDepthSearch)
      {
          ss[sp->ply].reduction = Depth(0);
          value = -search(pos, ss, -(sp->beta - 1), newDepth, sp->ply+1, true, threadID);
      }

      // Step 16. Undo move
      pos.undo_move(move);

      assert(value > -VALUE_INFINITE && value < VALUE_INFINITE);

      // Step 17. Check for new best move
      lock_grab(&(sp->lock));

      if (value > sp->bestValue && !TM.thread_should_stop(threadID))
      {
          sp->bestValue = value;
          if (sp->bestValue >= sp->beta)
          {
              sp->stopRequest = true;
              sp_update_pv(sp->parentSstack, ss, sp->ply);
          }
      }
    }

    /* Here we have the lock still grabbed */

    sp->slaves[threadID] = 0;
    sp->cpus--;

    lock_release(&(sp->lock));
  }


  // sp_search_pv() is used to search from a PV split point.  This function
  // is called by each thread working at the split point.  It is similar to
  // the normal search_pv() function, but simpler.  Because we have already
  // probed the hash table and searched the first move before splitting, we
  // don't have to repeat all this work in sp_search_pv().  We also don't
  // need to store anything to the hash table here: This is taken care of
  // after we return from the split point.

  void sp_search_pv(SplitPoint* sp, int threadID) {

    assert(threadID >= 0 && threadID < TM.active_threads());
    assert(TM.active_threads() > 1);

    StateInfo st;
    Move move;
    Depth ext, newDepth;
    Value value;
    bool moveIsCheck, captureOrPromotion, dangerous;
    int moveCount;
    value = -VALUE_INFINITE;

    Position pos(*sp->pos);
    CheckInfo ci(pos);
    SearchStack* ss = sp->sstack[threadID];

    // Step 10. Loop through moves
    // Loop through all legal moves until no moves remain or a beta cutoff occurs
    lock_grab(&(sp->lock));

    while (    sp->alpha < sp->beta
           && !TM.thread_should_stop(threadID)
           && (move = sp->mp->get_next_move()) != MOVE_NONE)
    {
      moveCount = ++sp->moves;
      lock_release(&(sp->lock));

      assert(move_is_ok(move));

      moveIsCheck = pos.move_is_check(move, ci);
      captureOrPromotion = pos.move_is_capture_or_promotion(move);

      // Step 11. Decide the new search depth
      ext = extension(pos, move, true, captureOrPromotion, moveIsCheck, false, sp->mateThreat, &dangerous);
      newDepth = sp->depth - OnePly + ext;

      // Update current move
      ss[sp->ply].currentMove = move;

      // Step 12. Futility pruning (is omitted in PV nodes)

      // Step 13. Make the move
      pos.do_move(move, st, ci, moveIsCheck);

      // Step 14. Reduced search
      // if the move fails high will be re-searched at full depth.
      bool doFullDepthSearch = true;

      if (   !dangerous
          && !captureOrPromotion
          && !move_is_castle(move)
          && !move_is_killer(move, ss[sp->ply]))
      {
          ss[sp->ply].reduction = pv_reduction(sp->depth, moveCount);
          if (ss[sp->ply].reduction)
          {
              Value localAlpha = sp->alpha;
              value = -search(pos, ss, -localAlpha, newDepth-ss[sp->ply].reduction, sp->ply+1, true, threadID);
              doFullDepthSearch = (value > localAlpha && !TM.thread_should_stop(threadID));
          }
      }

      // Step 15. Full depth search
      if (doFullDepthSearch)
      {
          Value localAlpha = sp->alpha;
          ss[sp->ply].reduction = Depth(0);
          value = -search(pos, ss, -localAlpha, newDepth, sp->ply+1, true, threadID);

          if (value > localAlpha && value < sp->beta && !TM.thread_should_stop(threadID))
          {
              // If another thread has failed high then sp->alpha has been increased
              // to be higher or equal then beta, if so, avoid to start a PV search.
              localAlpha = sp->alpha;
              if (localAlpha < sp->beta)
                  value = -search_pv(pos, ss, -sp->beta, -localAlpha, newDepth, sp->ply+1, threadID);
          }
      }

      // Step 16. Undo move
      pos.undo_move(move);

      assert(value > -VALUE_INFINITE && value < VALUE_INFINITE);

      // Step 17. Check for new best move
      lock_grab(&(sp->lock));

      if (value > sp->bestValue && !TM.thread_should_stop(threadID))
      {
          sp->bestValue = value;
          if (value > sp->alpha)
          {
              // Ask threads to stop before to modify sp->alpha
              if (value >= sp->beta)
                  sp->stopRequest = true;

              sp->alpha = value;

              sp_update_pv(sp->parentSstack, ss, sp->ply);
              if (value == value_mate_in(sp->ply + 1))
                  ss[sp->ply].mateKiller = move;
          }
      }
    }

    /* Here we have the lock still grabbed */

    sp->slaves[threadID] = 0;
    sp->cpus--;

    lock_release(&(sp->lock));
  }


  // init_node() is called at the beginning of all the search functions
  // (search(), search_pv(), qsearch(), and so on) and initializes the
  // search stack object corresponding to the current node. Once every
  // NodesBetweenPolls nodes, init_node() also calls poll(), which polls
  // for user input and checks whether it is time to stop the search.

  void init_node(const Position& pos, SearchStack ss[], int ply, int threadID) {

    assert(ply >= 0 && ply < PLY_MAX);
    assert(threadID >= 0 && threadID < TM.active_threads());

    if (Slowdown && Iteration >= 3)
        slowdown(pos);

    TM.incrementNodeCounter(threadID);

    if (threadID == 0)
    {
        NodesSincePoll++;
        if (NodesSincePoll >= NodesBetweenPolls)
        {
            poll();
            NodesSincePoll = 0;
        }
    }
    ss[ply].init(ply);
    ss[ply + 2].initKillers();
  }


  // update_pv() is called whenever a search returns a value > alpha.
  // It updates the PV in the SearchStack object corresponding to the
  // current node.

  void update_pv(SearchStack ss[], int ply) {

    assert(ply >= 0 && ply < PLY_MAX);

    int p;

    ss[ply].pv[ply] = ss[ply].currentMove;

    for (p = ply + 1; ss[ply + 1].pv[p] != MOVE_NONE; p++)
        ss[ply].pv[p] = ss[ply + 1].pv[p];

    ss[ply].pv[p] = MOVE_NONE;
  }


  // sp_update_pv() is a variant of update_pv for use at split points. The
  // difference between the two functions is that sp_update_pv also updates
  // the PV at the parent node.

  void sp_update_pv(SearchStack* pss, SearchStack ss[], int ply) {

    assert(ply >= 0 && ply < PLY_MAX);

    int p;

    ss[ply].pv[ply] = pss[ply].pv[ply] = ss[ply].currentMove;

    for (p = ply + 1; ss[ply + 1].pv[p] != MOVE_NONE; p++)
        ss[ply].pv[p] = pss[ply].pv[p] = ss[ply + 1].pv[p];

    ss[ply].pv[p] = pss[ply].pv[p] = MOVE_NONE;
  }


  // connected_moves() tests whether two moves are 'connected' in the sense
  // that the first move somehow made the second move possible (for instance
  // if the moving piece is the same in both moves). The first move is assumed
  // to be the move that was made to reach the current position, while the
  // second move is assumed to be a move from the current position.

  bool connected_moves(const Position& pos, Move m1, Move m2) {

    Square f1, t1, f2, t2;
    Piece p;

    assert(move_is_ok(m1));
    assert(move_is_ok(m2));

    if (m2 == MOVE_NONE)
        return false;

    // Case 1: The moving piece is the same in both moves
    f2 = move_from(m2);
    t1 = move_to(m1);
    if (f2 == t1)
        return true;

    // Case 2: The destination square for m2 was vacated by m1
    t2 = move_to(m2);
    f1 = move_from(m1);
    if (t2 == f1)
        return true;

    // Case 3: Moving through the vacated square
    if (   piece_is_slider(pos.piece_on(f2))
        && bit_is_set(squares_between(f2, t2), f1))
      return true;

    // Case 4: The destination square for m2 is defended by the moving piece in m1
    p = pos.piece_on(t1);
    if (bit_is_set(pos.attacks_from(p, t1), t2))
        return true;

    // Case 5: Discovered check, checking piece is the piece moved in m1
    if (    piece_is_slider(p)
        &&  bit_is_set(squares_between(t1, pos.king_square(pos.side_to_move())), f2)
        && !bit_is_set(squares_between(t1, pos.king_square(pos.side_to_move())), t2))
    {
        // discovered_check_candidates() works also if the Position's side to
        // move is the opposite of the checking piece.
        Color them = opposite_color(pos.side_to_move());
        Bitboard dcCandidates = pos.discovered_check_candidates(them);

        if (bit_is_set(dcCandidates, f2))
            return true;
    }
    return false;
  }


  // value_is_mate() checks if the given value is a mate one
  // eventually compensated for the ply.

  bool value_is_mate(Value value) {

    assert(abs(value) <= VALUE_INFINITE);

    return   value <= value_mated_in(PLY_MAX)
          || value >= value_mate_in(PLY_MAX);
  }


  // move_is_killer() checks if the given move is among the
  // killer moves of that ply.

  bool move_is_killer(Move m, const SearchStack& ss) {

      const Move* k = ss.killers;
      for (int i = 0; i < KILLER_MAX; i++, k++)
          if (*k == m)
              return true;

      return false;
  }


  // extension() decides whether a move should be searched with normal depth,
  // or with extended depth. Certain classes of moves (checking moves, in
  // particular) are searched with bigger depth than ordinary moves and in
  // any case are marked as 'dangerous'. Note that also if a move is not
  // extended, as example because the corresponding UCI option is set to zero,
  // the move is marked as 'dangerous' so, at least, we avoid to prune it.

  Depth extension(const Position& pos, Move m, bool pvNode, bool captureOrPromotion,
                  bool moveIsCheck, bool singleEvasion, bool mateThreat, bool* dangerous) {

    assert(m != MOVE_NONE);

    Depth result = Depth(0);
    *dangerous = moveIsCheck | singleEvasion | mateThreat;

    if (*dangerous)
    {
        if (moveIsCheck)
            result += CheckExtension[pvNode];

        if (singleEvasion)
            result += SingleEvasionExtension[pvNode];

        if (mateThreat)
            result += MateThreatExtension[pvNode];
    }

    if (pos.type_of_piece_on(move_from(m)) == PAWN)
    {
        Color c = pos.side_to_move();
        if (relative_rank(c, move_to(m)) == RANK_7)
        {
            result += PawnPushTo7thExtension[pvNode];
            *dangerous = true;
        }
        if (pos.pawn_is_passed(c, move_to(m)))
        {
            result += PassedPawnExtension[pvNode];
            *dangerous = true;
        }
    }

    if (   captureOrPromotion
        && pos.type_of_piece_on(move_to(m)) != PAWN
        && (  pos.non_pawn_material(WHITE) + pos.non_pawn_material(BLACK)
            - pos.midgame_value_of_piece_on(move_to(m)) == Value(0))
        && !move_is_promotion(m)
        && !move_is_ep(m))
    {
        result += PawnEndgameExtension[pvNode];
        *dangerous = true;
    }

    if (   pvNode
        && captureOrPromotion
        && pos.type_of_piece_on(move_to(m)) != PAWN
        && pos.see_sign(m) >= 0)
    {
        result += OnePly/2;
        *dangerous = true;
    }

    return Min(result, OnePly);
  }


  // ok_to_do_nullmove() looks at the current position and decides whether
  // doing a 'null move' should be allowed. In order to avoid zugzwang
  // problems, null moves are not allowed when the side to move has very
  // little material left. Currently, the test is a bit too simple: Null
  // moves are avoided only when the side to move has only pawns left.
  // It's probably a good idea to avoid null moves in at least some more
  // complicated endgames, e.g. KQ vs KR.  FIXME

  bool ok_to_do_nullmove(const Position& pos) {

    return pos.non_pawn_material(pos.side_to_move()) != Value(0);
  }


  // ok_to_prune() tests whether it is safe to forward prune a move. Only
  // non-tactical moves late in the move list close to the leaves are
  // candidates for pruning.

  bool ok_to_prune(const Position& pos, Move m, Move threat) {

    assert(move_is_ok(m));
    assert(threat == MOVE_NONE || move_is_ok(threat));
    assert(!pos.move_is_check(m));
    assert(!pos.move_is_capture_or_promotion(m));
    assert(!pos.move_is_passed_pawn_push(m));

    Square mfrom, mto, tfrom, tto;

    // Prune if there isn't any threat move
    if (threat == MOVE_NONE)
        return true;

    mfrom = move_from(m);
    mto = move_to(m);
    tfrom = move_from(threat);
    tto = move_to(threat);

    // Case 1: Don't prune moves which move the threatened piece
    if (mfrom == tto)
        return false;

    // Case 2: If the threatened piece has value less than or equal to the
    // value of the threatening piece, don't prune move which defend it.
    if (   pos.move_is_capture(threat)
        && (   pos.midgame_value_of_piece_on(tfrom) >= pos.midgame_value_of_piece_on(tto)
            || pos.type_of_piece_on(tfrom) == KING)
        && pos.move_attacks_square(m, tto))
        return false;

    // Case 3: If the moving piece in the threatened move is a slider, don't
    // prune safe moves which block its ray.
    if (   piece_is_slider(pos.piece_on(tfrom))
        && bit_is_set(squares_between(tfrom, tto), mto)
        && pos.see_sign(m) >= 0)
        return false;

    return true;
  }


  // ok_to_use_TT() returns true if a transposition table score can be used at a
  // given point in search. To avoid zugzwang issues TT cutoffs at the root node
  // of a null move verification search are not allowed if the TT value was found
  // by a null search, this is implemented testing allowNullmove and TT entry type.

  bool ok_to_use_TT(const TTEntry* tte, Depth depth, Value beta, int ply, bool allowNullmove) {

    Value v = value_from_tt(tte->value(), ply);

    return   (allowNullmove || !(tte->type() & VALUE_TYPE_NULL) || !ZugDetection)

          && (   tte->depth() >= depth
              || v >= Max(value_mate_in(PLY_MAX), beta)
              || v < Min(value_mated_in(PLY_MAX), beta))

          && (   (is_lower_bound(tte->type()) && v >= beta)
              || (is_upper_bound(tte->type()) && v < beta));
  }


  // refine_eval() returns the transposition table score if
  // possible otherwise falls back on static position evaluation.

  Value refine_eval(const TTEntry* tte, Value defaultEval, int ply) {

      if (!tte)
          return defaultEval;

      Value v = value_from_tt(tte->value(), ply);

      if (   (is_lower_bound(tte->type()) && v >= defaultEval)
          || (is_upper_bound(tte->type()) && v < defaultEval))
          return v;

      return defaultEval;
  }


  // update_history() registers a good move that produced a beta-cutoff
  // in history and marks as failures all the other moves of that ply.

  void update_history(const Position& pos, Move move, Depth depth,
                      Move movesSearched[], int moveCount) {

    Move m;

    H.success(pos.piece_on(move_from(move)), move_to(move), depth);

    for (int i = 0; i < moveCount - 1; i++)
    {
        m = movesSearched[i];

        assert(m != move);

        if (!pos.move_is_capture_or_promotion(m))
            H.failure(pos.piece_on(move_from(m)), move_to(m), depth);
    }
  }


  // update_killers() add a good move that produced a beta-cutoff
  // among the killer moves of that ply.

  void update_killers(Move m, SearchStack& ss) {

    if (m == ss.killers[0])
        return;

    for (int i = KILLER_MAX - 1; i > 0; i--)
        ss.killers[i] = ss.killers[i - 1];

    ss.killers[0] = m;
  }


  // update_gains() updates the gains table of a non-capture move given
  // the static position evaluation before and after the move.

  void update_gains(const Position& pos, Move m, Value before, Value after) {

    if (   m != MOVE_NULL
        && before != VALUE_NONE
        && after != VALUE_NONE
        && pos.captured_piece() == NO_PIECE_TYPE
        && !move_is_castle(m)
        && !move_is_promotion(m))
        H.set_gain(pos.piece_on(move_to(m)), move_to(m), -(before + after));
  }


  // slowdown() simply wastes CPU cycles doing nothing useful. It's used
  // in strength handicap mode.

  void slowdown(const Position &pos) {
    int i, n;
    n = Slowdown;
    for (i = 0; i < n; i++)  {
        Square s = Square(i&63);
        if (count_1s<false>(pos.attackers_to(s)) > 63)
            std::cout << "This can't happen, but I put this string here anyway, in order to prevent the compiler from optimizing away the useless computation." << std::endl;
    }
  }


  int blunder_modulus(const Position& pos, Move m, Depth d) {
     assert(Blunder > 0);
     assert(!pos.is_check());

     int blunder = (Blunder * d) / 3;
     int see = pos.see(m);

     if (blunder < 1) blunder = 1;

     // Increase probability of blunder if the move appears to lose material:
     if (see < 0)
        blunder /= 8;

     // Decrease probability if move is a capture, especially if it's a capture
     // of the piece that just moved:
     else if (pos.move_is_capture(m)) {
        blunder *= 4;
        /*
        if (move_to(m) == move_to(pos.last_move()))
           blunder *= 4;
        */
     }

     // Increase probability for long diagonal moves, especially if they are
     // diagonal:
     if (square_distance(move_from(m), move_to(m)) >= 5) {
        if (square_file(move_from(m)) != square_file(move_to(m)) 
            && square_rank(move_from(m)) != square_rank(move_to(m)))
           blunder /= 4;
        else
           blunder /= 2;
     }

     if (blunder < 1)
        blunder = 1;

     return blunder;
  }


  // current_search_time() returns the number of milliseconds which have passed
  // since the beginning of the current search.

  int current_search_time() {

    return get_system_time() - SearchStartTime;
  }


  // nps() computes the current nodes/second count.

  int nps() {

    int t = current_search_time();
    return (t > 0 ? int((TM.nodes_searched() * 1000) / t) : 0);
  }


  // poll() performs two different functions: It polls for user input, and it
  // looks at the time consumed so far and decides if it's time to abort the
  // search.

  void poll() {

    static int lastInfoTime;
    int t = current_search_time();

    //  Poll for input
#if !defined(IPHONE_GLAURUNG)
    if (Bioskey())
    {
        // We are line oriented, don't read single chars
        std::string command;

        if (!std::getline(std::cin, command))
            command = "quit";

        if (command == "quit")
        {
            AbortSearch = true;
            PonderSearch = false;
            Quit = true;
            return;
        }
        else if (command == "stop")
        {
            AbortSearch = true;
            PonderSearch = false;
        }
        else if (command == "ponderhit")
            ponderhit();
    }
#else
    if (command_is_waiting())
    {
        std::string command = get_command();
        if (command == "quit")
        {
            AbortSearch = true;
            PonderSearch = false;
            Quit = true;
            return;
        }
        else if (command == "stop")
        {
            AbortSearch = true;
            PonderSearch = false;
        }
        else if (command == "ponderhit")
            ponderhit();
    }
#endif

    // Print search information
    if (t < 1000)
        lastInfoTime = 0;

    else if (lastInfoTime > t)
        // HACK: Must be a new search where we searched less than
        // NodesBetweenPolls nodes during the first second of search.
        lastInfoTime = 0;

    else if (t - lastInfoTime >= 1000)
    {
        lastInfoTime = t;

        if (dbg_show_mean)
            dbg_print_mean();

        if (dbg_show_hit_rate)
            dbg_print_hit_rate();

        cout << "info nodes " << TM.nodes_searched() << " nps " << nps()
             << " time " << t << " hashfull " << TT.full() << endl;

#if defined(IPHONE_GLAURUNG)
        searchstats_to_ui(Iteration, nodes_searched(), t);
#endif
    }

    // Should we stop the search?
    if (PonderSearch)
        return;

    bool stillAtFirstMove =    FirstRootMove
                           && !AspirationFailLow
                           &&  t > MaxSearchTime + ExtraSearchTime;

    bool noMoreTime =   t > AbsoluteMaxSearchTime
                     || stillAtFirstMove;

    if (   (Iteration >= 3 && UseTimeManagement && noMoreTime)
        || (ExactMaxTime && t >= ExactMaxTime)
        || (Iteration >= 3 && MaxNodes && TM.nodes_searched() >= MaxNodes))
        AbortSearch = true;
  }


  // ponderhit() is called when the program is pondering (i.e. thinking while
  // it's the opponent's turn to move) in order to let the engine know that
  // it correctly predicted the opponent's move.

  void ponderhit() {

    int t = current_search_time();
    PonderSearch = false;

    bool stillAtFirstMove =    FirstRootMove
                           && !AspirationFailLow
                           &&  t > MaxSearchTime + ExtraSearchTime;

    bool noMoreTime =   t > AbsoluteMaxSearchTime
                     || stillAtFirstMove;

    if (Iteration >= 3 && UseTimeManagement && (noMoreTime || StopOnPonderhit))
        AbortSearch = true;
  }


  // init_ss_array() does a fast reset of the first entries of a SearchStack array

  void init_ss_array(SearchStack ss[]) {

    for (int i = 0; i < 3; i++)
    {
        ss[i].init(i);
        ss[i].initKillers();
    }
  }


  // wait_for_stop_or_ponderhit() is called when the maximum depth is reached
  // while the program is pondering. The point is to work around a wrinkle in
  // the UCI protocol: When pondering, the engine is not allowed to give a
  // "bestmove" before the GUI sends it a "stop" or "ponderhit" command.
  // We simply wait here until one of these commands is sent, and return,
  // after which the bestmove and pondermove will be printed (in id_loop()).

  void wait_for_stop_or_ponderhit() {

    std::string command;

    while (true)
    {
        if (!std::getline(std::cin, command))
            command = "quit";

        if (command == "quit")
        {
            Quit = true;
            break;
        }
        else if (command == "ponderhit" || command == "stop")
            break;
    }
  }


  // print_pv_info() prints to standard output and eventually to log file information on
  // the current PV line. It is called at each iteration or after a new pv is found.

  void print_pv_info(const Position& pos, SearchStack ss[], Value alpha, Value beta, Value value) {

    cout << "info depth " << Iteration
         << " score " << value_to_string(value)
         << ((value >= beta) ? " lowerbound" :
            ((value <= alpha)? " upperbound" : ""))
         << " time "  << current_search_time()
         << " nodes " << TM.nodes_searched()
         << " nps "   << nps()
         << " pv ";

    for (int j = 0; ss[0].pv[j] != MOVE_NONE && j < PLY_MAX; j++)
        cout << ss[0].pv[j] << " ";

    cout << endl;

#if !defined(IPHONE_GLAURUNG)
    if (UseLogFile)
    {
        ValueType type =  (value >= beta  ? VALUE_TYPE_LOWER
            : (value <= alpha ? VALUE_TYPE_UPPER : VALUE_TYPE_EXACT));

        LogFile << pretty_pv(pos, current_search_time(), Iteration,
                             TM.nodes_searched(), value, type, ss[0].pv) << endl;
    }
#else
    std::stringstream str;
    bool iAmWhite = (pos.side_to_move() == WHITE);
    str << Iteration << " ";
    if ((value >= beta && iAmWhite) || (value <= alpha && !iAmWhite))
      str << ">";
    else if ((value >= beta && !iAmWhite) || (value <= alpha && iAmWhite))
      str << "<";
    if (abs(value) >= VALUE_MATE - 200) {
      if (value < 0)
        str << (iAmWhite? '-' : '+') << '#'
            << (VALUE_MATE + value) / 2;
      else
        str << (iAmWhite? '+' : '-') << '#'
            << (VALUE_MATE - value + 1) / 2;
    }
    else
      str << (((iAmWhite && value > 0) || (!iAmWhite && value < 0))? "+" : "")
          << std::setiosflags(std::ios::fixed) << std::setprecision(1)
          << value_to_centipawns(iAmWhite? value : -value) / 100.0;
    str << " " << line_to_san(pos, ss[0].pv, 0, false, 0);
    pv_to_ui(str.str());
#endif
    
  }


  // init_thread() is the function which is called when a new thread is
  // launched. It simply calls the idle_loop() function with the supplied
  // threadID. There are two versions of this function; one for POSIX
  // threads and one for Windows threads.

#if !defined(_MSC_VER)

  void* init_thread(void *threadID) {

    TM.idle_loop(*(int*)threadID, NULL);
    return NULL;
  }

#else

  DWORD WINAPI init_thread(LPVOID threadID) {

    TM.idle_loop(*(int*)threadID, NULL);
    return 0;
  }

#endif


  /// The ThreadsManager class

  // resetNodeCounters(), resetBetaCounters(), searched_nodes() and
  // get_beta_counters() are getters/setters for the per thread
  // counters used to sort the moves at root.

  void ThreadsManager::resetNodeCounters() {

    for (int i = 0; i < MAX_THREADS; i++)
        threads[i].nodes = 0ULL;
  }

  void ThreadsManager::resetBetaCounters() {

    for (int i = 0; i < MAX_THREADS; i++)
        threads[i].betaCutOffs[WHITE] = threads[i].betaCutOffs[BLACK] = 0ULL;
  }

  int64_t ThreadsManager::nodes_searched() const {

    int64_t result = 0ULL;
    for (int i = 0; i < ActiveThreads; i++)
        result += threads[i].nodes;

    return result;
  }

  void ThreadsManager::get_beta_counters(Color us, int64_t& our, int64_t& their) const {

    our = their = 0UL;
    for (int i = 0; i < MAX_THREADS; i++)
    {
        our += threads[i].betaCutOffs[us];
        their += threads[i].betaCutOffs[opposite_color(us)];
    }
  }


  // idle_loop() is where the threads are parked when they have no work to do.
  // The parameter "waitSp", if non-NULL, is a pointer to an active SplitPoint
  // object for which the current thread is the master.

  void ThreadsManager::idle_loop(int threadID, SplitPoint* waitSp) {

    assert(threadID >= 0 && threadID < MAX_THREADS);

    while (true)
    {
        // Slave threads can exit as soon as AllThreadsShouldExit raises,
        // master should exit as last one.
        if (AllThreadsShouldExit)
        {
            assert(!waitSp);
            threads[threadID].state = THREAD_TERMINATED;
            return;
        }

        // If we are not thinking, wait for a condition to be signaled
        // instead of wasting CPU time polling for work.
        while (AllThreadsShouldSleep || threadID >= ActiveThreads)
        {
            assert(!waitSp);
            assert(threadID != 0);
            threads[threadID].state = THREAD_SLEEPING;

#if !defined(_MSC_VER)
            lock_grab(&WaitLock);
            if (AllThreadsShouldSleep || threadID >= ActiveThreads)
                pthread_cond_wait(&WaitCond, &WaitLock);
            lock_release(&WaitLock);
#else
            WaitForSingleObject(SitIdleEvent[threadID], INFINITE);
#endif
        }

        // If thread has just woken up, mark it as available
        if (threads[threadID].state == THREAD_SLEEPING)
            threads[threadID].state = THREAD_AVAILABLE;

        // If this thread has been assigned work, launch a search
        if (threads[threadID].state == THREAD_WORKISWAITING)
        {
            assert(!AllThreadsShouldExit && !AllThreadsShouldSleep);

            threads[threadID].state = THREAD_SEARCHING;

            if (threads[threadID].splitPoint->pvNode)
                sp_search_pv(threads[threadID].splitPoint, threadID);
            else
                sp_search(threads[threadID].splitPoint, threadID);

            assert(threads[threadID].state == THREAD_SEARCHING);

            threads[threadID].state = THREAD_AVAILABLE;
        }

        // If this thread is the master of a split point and all threads have
        // finished their work at this split point, return from the idle loop.
        if (waitSp != NULL && waitSp->cpus == 0)
        {
            assert(threads[threadID].state == THREAD_AVAILABLE);

            threads[threadID].state = THREAD_SEARCHING;
            return;
        }
    }
  }


  // init_threads() is called during startup. It launches all helper threads,
  // and initializes the split point stack and the global locks and condition
  // objects.

  void ThreadsManager::init_threads() {

    volatile int i;
    bool ok;

#if !defined(_MSC_VER)
    pthread_t pthread[1];
#endif

    // Initialize global locks
    lock_init(&MPLock, NULL);
    lock_init(&WaitLock, NULL);

#if !defined(_MSC_VER)
    pthread_cond_init(&WaitCond, NULL);
#else
    for (i = 0; i < MAX_THREADS; i++)
        SitIdleEvent[i] = CreateEvent(0, FALSE, FALSE, 0);
#endif

    // Initialize SplitPointStack locks
    for (i = 0; i < MAX_THREADS; i++)
        for (int j = 0; j < ACTIVE_SPLIT_POINTS_MAX; j++)
        {
            SplitPointStack[i][j].parent = NULL;
            lock_init(&(SplitPointStack[i][j].lock), NULL);
        }

    // Will be set just before program exits to properly end the threads
    AllThreadsShouldExit = false;

    // Threads will be put to sleep as soon as created
    AllThreadsShouldSleep = true;

    // All threads except the main thread should be initialized to THREAD_AVAILABLE
    ActiveThreads = 1;
    threads[0].state = THREAD_SEARCHING;
    for (i = 1; i < MAX_THREADS; i++)
        threads[i].state = THREAD_AVAILABLE;

    // Launch the helper threads
    for (i = 1; i < MAX_THREADS; i++)
    {

#if !defined(_MSC_VER)
        ok = (pthread_create(pthread, NULL, init_thread, (void*)(&i)) == 0);
#else
        ok = (CreateThread(NULL, 0, init_thread, (LPVOID)(&i), 0, NULL) != NULL);
#endif

        if (!ok)
        {
            cout << "Failed to create thread number " << i << endl;
            Application::exit_with_failure();
        }

        // Wait until the thread has finished launching and is gone to sleep
        while (threads[i].state != THREAD_SLEEPING);
    }
  }


  // exit_threads() is called when the program exits. It makes all the
  // helper threads exit cleanly.

  void ThreadsManager::exit_threads() {

    ActiveThreads = MAX_THREADS;  // HACK
    AllThreadsShouldSleep = true;  // HACK
    wake_sleeping_threads();

    // This makes the threads to exit idle_loop()
    AllThreadsShouldExit = true;

    // Wait for thread termination
    for (int i = 1; i < MAX_THREADS; i++)
        while (threads[i].state != THREAD_TERMINATED);

    // Now we can safely destroy the locks
    for (int i = 0; i < MAX_THREADS; i++)
        for (int j = 0; j < ACTIVE_SPLIT_POINTS_MAX; j++)
            lock_destroy(&(SplitPointStack[i][j].lock));

    lock_destroy(&WaitLock);
    lock_destroy(&MPLock);
  }


  // thread_should_stop() checks whether the thread should stop its search.
  // This can happen if a beta cutoff has occurred in the thread's currently
  // active split point, or in some ancestor of the current split point.

  bool ThreadsManager::thread_should_stop(int threadID) const {

    assert(threadID >= 0 && threadID < ActiveThreads);

    SplitPoint* sp;

    for (sp = threads[threadID].splitPoint; sp && !sp->stopRequest; sp = sp->parent);
    return sp != NULL;
  }


  // thread_is_available() checks whether the thread with threadID "slave" is
  // available to help the thread with threadID "master" at a split point. An
  // obvious requirement is that "slave" must be idle. With more than two
  // threads, this is not by itself sufficient:  If "slave" is the master of
  // some active split point, it is only available as a slave to the other
  // threads which are busy searching the split point at the top of "slave"'s
  // split point stack (the "helpful master concept" in YBWC terminology).

  bool ThreadsManager::thread_is_available(int slave, int master) const {

    assert(slave >= 0 && slave < ActiveThreads);
    assert(master >= 0 && master < ActiveThreads);
    assert(ActiveThreads > 1);

    if (threads[slave].state != THREAD_AVAILABLE || slave == master)
        return false;

    // Make a local copy to be sure doesn't change under our feet
    int localActiveSplitPoints = threads[slave].activeSplitPoints;

    if (localActiveSplitPoints == 0)
        // No active split points means that the thread is available as
        // a slave for any other thread.
        return true;

    if (ActiveThreads == 2)
        return true;

    // Apply the "helpful master" concept if possible. Use localActiveSplitPoints
    // that is known to be > 0, instead of threads[slave].activeSplitPoints that
    // could have been set to 0 by another thread leading to an out of bound access.
    if (SplitPointStack[slave][localActiveSplitPoints - 1].slaves[master])
        return true;

    return false;
  }


  // available_thread_exists() tries to find an idle thread which is available as
  // a slave for the thread with threadID "master".

  bool ThreadsManager::available_thread_exists(int master) const {

    assert(master >= 0 && master < ActiveThreads);
    assert(ActiveThreads > 1);

    for (int i = 0; i < ActiveThreads; i++)
        if (thread_is_available(i, master))
            return true;

    return false;
  }


  // split() does the actual work of distributing the work at a node between
  // several threads at PV nodes. If it does not succeed in splitting the
  // node (because no idle threads are available, or because we have no unused
  // split point objects), the function immediately returns false. If
  // splitting is possible, a SplitPoint object is initialized with all the
  // data that must be copied to the helper threads (the current position and
  // search stack, alpha, beta, the search depth, etc.), and we tell our
  // helper threads that they have been assigned work. This will cause them
  // to instantly leave their idle loops and call sp_search_pv(). When all
  // threads have returned from sp_search_pv (or, equivalently, when
  // splitPoint->cpus becomes 0), split() returns true.

  bool ThreadsManager::split(const Position& p, SearchStack* sstck, int ply,
             Value* alpha, const Value beta, Value* bestValue,
             Depth depth, bool mateThreat, int* moves, MovePicker* mp, int master, bool pvNode) {

    assert(p.is_ok());
    assert(sstck != NULL);
    assert(ply >= 0 && ply < PLY_MAX);
    assert(*bestValue >= -VALUE_INFINITE);
    assert(   ( pvNode && *bestValue <= *alpha)
           || (!pvNode && *bestValue <   beta ));
    assert(!pvNode || *alpha < beta);
    assert(beta <= VALUE_INFINITE);
    assert(depth > Depth(0));
    assert(master >= 0 && master < ActiveThreads);
    assert(ActiveThreads > 1);

    SplitPoint* splitPoint;

    lock_grab(&MPLock);

    // If no other thread is available to help us, or if we have too many
    // active split points, don't split.
    if (   !available_thread_exists(master)
        || threads[master].activeSplitPoints >= ACTIVE_SPLIT_POINTS_MAX)
    {
        lock_release(&MPLock);
        return false;
    }

    // Pick the next available split point object from the split point stack
    splitPoint = &SplitPointStack[master][threads[master].activeSplitPoints];

    // Initialize the split point object
    splitPoint->parent = threads[master].splitPoint;
    splitPoint->stopRequest = false;
    splitPoint->ply = ply;
    splitPoint->depth = depth;
    splitPoint->mateThreat = mateThreat;
    splitPoint->alpha = pvNode ? *alpha : beta - 1;
    splitPoint->beta = beta;
    splitPoint->pvNode = pvNode;
    splitPoint->bestValue = *bestValue;
    splitPoint->master = master;
    splitPoint->mp = mp;
    splitPoint->moves = *moves;
    splitPoint->cpus = 1;
    splitPoint->pos = &p;
    splitPoint->parentSstack = sstck;
    for (int i = 0; i < ActiveThreads; i++)
        splitPoint->slaves[i] = 0;

    threads[master].splitPoint = splitPoint;
    threads[master].activeSplitPoints++;

    // If we are here it means we are not available
    assert(threads[master].state != THREAD_AVAILABLE);

    // Allocate available threads setting state to THREAD_BOOKED
    for (int i = 0; i < ActiveThreads && splitPoint->cpus < MaxThreadsPerSplitPoint; i++)
        if (thread_is_available(i, master))
        {
            threads[i].state = THREAD_BOOKED;
            threads[i].splitPoint = splitPoint;
            splitPoint->slaves[i] = 1;
            splitPoint->cpus++;
        }

    assert(splitPoint->cpus > 1);

    // We can release the lock because slave threads are already booked and master is not available
    lock_release(&MPLock);

    // Tell the threads that they have work to do. This will make them leave
    // their idle loop. But before copy search stack tail for each thread.
    for (int i = 0; i < ActiveThreads; i++)
        if (i == master || splitPoint->slaves[i])
        {
            memcpy(splitPoint->sstack[i] + ply - 1, sstck + ply - 1, 4 * sizeof(SearchStack));

            assert(i == master || threads[i].state == THREAD_BOOKED);

            threads[i].state = THREAD_WORKISWAITING; // This makes the slave to exit from idle_loop()
        }

    // Everything is set up. The master thread enters the idle loop, from
    // which it will instantly launch a search, because its state is
    // THREAD_WORKISWAITING.  We send the split point as a second parameter to the
    // idle loop, which means that the main thread will return from the idle
    // loop when all threads have finished their work at this split point
    // (i.e. when splitPoint->cpus == 0).
    idle_loop(master, splitPoint);

    // We have returned from the idle loop, which means that all threads are
    // finished. Update alpha, beta and bestValue, and return.
    lock_grab(&MPLock);

    if (pvNode)
        *alpha = splitPoint->alpha;

    *bestValue = splitPoint->bestValue;
    threads[master].activeSplitPoints--;
    threads[master].splitPoint = splitPoint->parent;

    lock_release(&MPLock);
    return true;
  }


  // wake_sleeping_threads() wakes up all sleeping threads when it is time
  // to start a new search from the root.

  void ThreadsManager::wake_sleeping_threads() {

    assert(AllThreadsShouldSleep);
    assert(ActiveThreads > 0);

    AllThreadsShouldSleep = false;

    if (ActiveThreads == 1)
        return;

#if !defined(_MSC_VER)
    pthread_mutex_lock(&WaitLock);
    pthread_cond_broadcast(&WaitCond);
    pthread_mutex_unlock(&WaitLock);
#else
    for (int i = 1; i < MAX_THREADS; i++)
        SetEvent(SitIdleEvent[i]);
#endif

  }


  // put_threads_to_sleep() makes all the threads go to sleep just before
  // to leave think(), at the end of the search. Threads should have already
  // finished the job and should be idle.

  void ThreadsManager::put_threads_to_sleep() {

    assert(!AllThreadsShouldSleep);

    // This makes the threads to go to sleep
    AllThreadsShouldSleep = true;
  }

  /// The RootMoveList class

  // RootMoveList c'tor

  RootMoveList::RootMoveList(Position& pos, Move searchMoves[]) : count(0) {

    SearchStack ss[PLY_MAX_PLUS_2];
    MoveStack mlist[MaxRootMoves];
    StateInfo st;
    bool includeAllMoves = (searchMoves[0] == MOVE_NONE);

    // Generate all legal moves
    MoveStack* last = generate_moves(pos, mlist);

    // Add each move to the moves[] array
    for (MoveStack* cur = mlist; cur != last; cur++)
    {
        bool includeMove = includeAllMoves;

        for (int k = 0; !includeMove && searchMoves[k] != MOVE_NONE; k++)
            includeMove = (searchMoves[k] == cur->move);

        if (!includeMove)
            continue;

        // Find a quick score for the move
        init_ss_array(ss);
        pos.do_move(cur->move, st);
        moves[count].move = cur->move;
        moves[count].score = -qsearch(pos, ss, -VALUE_INFINITE, VALUE_INFINITE, Depth(0), 1, 0);
        moves[count].pv[0] = cur->move;
        moves[count].pv[1] = MOVE_NONE;
        pos.undo_move(cur->move);
        count++;
    }
    sort();
  }


  // RootMoveList simple methods definitions

  void RootMoveList::set_move_nodes(int moveNum, int64_t nodes) {

    moves[moveNum].nodes = nodes;
    moves[moveNum].cumulativeNodes += nodes;
  }

  void RootMoveList::set_beta_counters(int moveNum, int64_t our, int64_t their) {

    moves[moveNum].ourBeta = our;
    moves[moveNum].theirBeta = their;
  }

  void RootMoveList::set_move_pv(int moveNum, const Move pv[]) {

    int j;

    for (j = 0; pv[j] != MOVE_NONE; j++)
        moves[moveNum].pv[j] = pv[j];

    moves[moveNum].pv[j] = MOVE_NONE;
  }


  // RootMoveList::sort() sorts the root move list at the beginning of a new
  // iteration.

  void RootMoveList::sort() {

    sort_multipv(count - 1); // Sort all items
  }


  // RootMoveList::sort_multipv() sorts the first few moves in the root move
  // list by their scores and depths. It is used to order the different PVs
  // correctly in MultiPV mode.

  void RootMoveList::sort_multipv(int n) {

    int i,j;

    for (i = 1; i <= n; i++)
    {
        RootMove rm = moves[i];
        for (j = i; j > 0 && moves[j - 1] < rm; j--)
            moves[j] = moves[j - 1];

        moves[j] = rm;
    }
  }

} // namspace
