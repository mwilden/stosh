/*
  Stockfish, a chess program for the Apple iPhone.
  Copyright (C) 2004-2010 Tord Romstad, Marco Costalba, Joona Kiiski.

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

#import <UIKit/UIKit.h>

#import "BoardView.h"
#import "RootView.h"

@class GameController;
@class MoveListView;

@interface BoardViewController : UIViewController <UIActionSheetDelegate> {
   RootView *rootView;
   UIView *contentView;
   BoardView *boardView;
   UILabel *searchStatsView;
   MoveListView *moveListView;
   GameController *gameController;
   UINavigationController *navigationController;
   UIActivityIndicatorView *activityIndicator;
   UIActionSheet *gameMenu, *newGameMenu, *moveMenu;
   UIBarButtonItem *gameButton, *optionsButton;
   UIPopoverController *optionsMenu, *saveMenu, *levelsMenu, *loadMenu;
   UIPopoverController *popoverMenu;
}

@property (nonatomic, readonly) BoardView *boardView;
@property (nonatomic, readonly) MoveListView *moveListView;
@property (nonatomic, readonly) UILabel *searchStatsView;
@property (nonatomic, assign) GameController *gameController;

- (void)toolbarButtonPressed:(id)sender;
- (void)showOptionsMenu;
- (void)optionsMenuDonePressed;
- (void)showLevelsMenu;
- (void)levelWasChanged;
- (void)gameModeWasChanged;
- (void)levelsMenuDonePressed;
- (void)editPosition;
- (void)editPositionCancelPressed;
- (void)editPositionDonePressed:(NSString *)fen;
- (void)showSaveGameMenu;
- (void)saveMenuDonePressed;
- (void)saveMenuCancelPressed;
- (void)showLoadGameMenu;
- (void)loadMenuCancelPressed;
- (void)loadMenuDonePressedWithGame:(NSString *)gameString;
- (void)stopActivityIndicator;
- (void)connectToServer;
- (void)disconnectFromServer;
- (BOOL)isConnectedToServer;

@end
