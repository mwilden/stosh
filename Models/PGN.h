#define SANDBOX

#if defined(SANDBOX)

const BOOL Sandbox = YES;

#  define PGN_DIRECTORY [NSHomeDirectory() stringByAppendingPathComponent: @"Documents"]
#  define ENGINE_NAME @"Stockfish"

#else

const BOOL Sandbox = NO;

#  if defined(TARGET_OS_IPHONE)
#    define PGN_DIRECTORY [NSString stringWithString: @"/var/mobile/Library/abaia"]
#  else
#    define PGN_DIRECTORY [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent: @"Documents"]
#  endif
#  define ENGINE_NAME @"Abaia"

#endif // defined(SANDBOX)

#define PGN_STRING_SIZE 256

@interface PGN : NSObject {
   NSString *filename;
   FILE *file;
   int fileSize;
   int charHack;
   int charColumn;
   BOOL charUnread;
   BOOL charFirst;
   int tokenType;
   char tokenString[PGN_STRING_SIZE];
   int tokenLength;
   BOOL tokenUnread;
   BOOL tokenFirst;
   int depth;
   int numberOfGames;
   int gameIndicesSize;
   int *gameIndices;
   char white[PGN_STRING_SIZE];
   char black[PGN_STRING_SIZE];
   char site[PGN_STRING_SIZE];
   char event[PGN_STRING_SIZE];
   char date[PGN_STRING_SIZE];
   char round[PGN_STRING_SIZE];
   char result[PGN_STRING_SIZE];
   char fen[PGN_STRING_SIZE];
}

- (id)initWithFilename:(NSString *)aFilename;
- (void)initializeGameIndices;
- (void)close;
- (BOOL)nextGame;
- (BOOL)nextMove:(NSString **)string;
- (void)rewind;
- (void)goToGameNumber:(int)number;
- (NSString *)pgnStringForGameNumber:(int)number;
- (NSString *)moveList;
- (int)numberOfGames;
- (NSString *)white;
- (NSString *)black;
- (NSString *)event;
- (NSString *)date;
- (NSString *)site;
- (NSString *)round;
- (NSString *)result;

@end
