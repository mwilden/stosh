////
//// Includes
////

#import "PGN.h"

#include <iomanip>
#include <string>
#include <sstream>

#include "application.h"
#include "iphone.h"
#include "san.h"
#include "uci.h"

using std::string;

namespace {
  string CurrentMove;
  int CurrentMoveNumber, TotalMoveCount;
}

////
//// Functions
////

void engine_init() {
  Application::initialize();
}

void pv_to_ui(const string &pv) {
}

void currmove_to_ui(const string currmove, int currmovenum, int movenum) {
  CurrentMove = currmove;
  CurrentMoveNumber = currmovenum;
  TotalMoveCount = movenum;
}

void searchstats_to_ui(int depth, int64_t nodes, int time) {
  std::stringstream s;
  s << " " << time_string(time) << "  " << depth
    << "  " << CurrentMove
    << " (" << CurrentMoveNumber << "/" << TotalMoveCount << ")"
    << "  " << nodes/1000 << "kN";
  if(time > 0)
    s << std::setiosflags(std::ios::fixed) << std::setprecision(1)
      << "  " <<  (nodes*1.0) / time << "kN/s";
}

void bestmove_to_ui(const string &best, const string &ponder) {
}

void command_to_engine(const string &command) {
  handle_command(command);
}

bool command_is_waiting() {
    return false;
}

string get_command() {
  return "";
}

string kpk_bitbase_filename() {
  return string([[PGN_DIRECTORY stringByAppendingPathComponent: @"kpk.bin"]
                  UTF8String]);
}
