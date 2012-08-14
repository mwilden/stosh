Feature: 

  Scenario: Launching the app without crashing
    Given I launch the app using iOS 5.1 and the ipad simulator
    And I play e4
    And Black plays d5
    And I play exd5
    Then captured pieces should show one black pawn
    And Black plays Qxd5
    Then captured pieces should show one white pawn and one black pawn
