//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import {Test} from "forge-std/Test.sol";
import {IWinWorldCup2K26} from "src/IWinWorldCup2K26.sol";
import {ReceiverTemplate} from "src/ReceiverTemplate.sol";


contract IWinWorldCup2k26Test is Test {
    address user;
    address user2;
    address user3;
    address keystoneForwarder;
    uint64 chainSelector;

    bytes32 expectedWorkflowId;
    bytes10 expectedWorkflowName;
    address expectedWorkflowOwner;
    IWinWorldCup2K26 IWin;
    receive() external payable {}

    function setUp() public {
       keystoneForwarder = makeAddr("Muyimbi");
    chainSelector = 16015286601757825753;

     expectedWorkflowId = bytes32("workflow");
     expectedWorkflowName = bytes10("IWIN");
     expectedWorkflowOwner = address(msg.sender);
        user = makeAddr("DiNormal");
        user2 = makeAddr("Raihan");
        user3 = makeAddr("Joy");
        vm.deal(user, 100 ether);
        vm.deal(user2, 100 ether);
        vm.deal(user3, 100 ether);

IWin = new IWinWorldCup2K26(
    keystoneForwarder,
    expectedWorkflowId,
    expectedWorkflowName,
    expectedWorkflowOwner,
    chainSelector
);
       
    }
    //this is a helper function.
    function _returnReport(uint256 betId, uint8 winner, uint256 nonce) internal {
    bytes memory metadata = abi.encodePacked(
        expectedWorkflowId,
        expectedWorkflowName,
        expectedWorkflowOwner
    );

    bytes memory report = abi.encode(
        betId,
        winner,
        chainSelector,
        nonce
    );

    vm.prank(keystoneForwarder);
    IWin.onReport(metadata, report);
}
    function testOwnerAddsFixture() public {
        IWin.addFixture("KCCA", "Vipers", "12345", 20 minutes, 100 minutes );
        (string memory teamA, string memory teamB) = IWin.getFixtureTeams(1);
        assertEq(teamA, "KCCA");
        assertEq(teamB, "Vipers");
        assertEq(IWin.getFixtureCount(), 1);
        
    }
    function testNonOwnerAddsFixtureFails() public {
        vm.prank(user);
        vm.expectRevert();
         IWin.addFixture("KCCA", "Vipers", "12345", 20 minutes, 100 minutes );

    }
    function testAddFixtureWithBettingDurationGreaterThanMatchDurationFails() public {
        vm.expectRevert(IWinWorldCup2K26.Disallowed.selector);
        IWin.addFixture("KCCA", "Vipers", "12345", 100 minutes, 90 minutes );
    }
    function testAddFixtureWithEmptyTeamNamesFails() public {
        vm.expectRevert(IWinWorldCup2K26.FieldsRequired.selector);
        IWin.addFixture("", "", "12345", 10 minutes, 90 minutes );

    }
    function testAddFixtureWithEmptyExternalApiIdFails() public {
       vm.expectRevert(IWinWorldCup2K26.FieldsRequired.selector);
        IWin.addFixture("KCCA", "Vipers", "", 20 minutes, 100 minutes );
    }
    function testUserCreatesBet() public {
        IWin.addFixture("KCCA", "Vipers", "12345", 20 minutes, 100 minutes );
        uint256 countBefore = IWin.getBetCount();
        vm.prank(user);
        IWin.createBet{value: 2 ether}(1, 2);
        uint256 countAfter = IWin.getBetCount();
        assertEq(countAfter, countBefore + 1);
        assertEq(IWin.getTotalBetAmount(1), 2 ether);
    }
     function testUserCreatesBetWithZeroEthFails() public {
    IWin.addFixture("KCCA", "Vipers", "12345", 20 minutes, 100 minutes );
    vm.prank(user);
    vm.expectRevert(IWinWorldCup2K26.AmountNotEnough.selector);
    IWin.createBet{value: 0 ether}(1, 2);
}
   function testUserCreatesBetWithInvalidOutcomeFails() public {
     IWin.addFixture("KCCA", "Vipers", "12345", 20 minutes, 100 minutes );
     vm.prank(user);
    vm.expectRevert(IWinWorldCup2K26.InvalidOutcomeValues.selector);
    IWin.createBet{value: 3 ether}(1, 4);
   }

   function testUserCreatesBetAfterDeadlineFails() public {
     IWin.addFixture("KCCA", "Vipers", "12345", 20 minutes, 100 minutes );
     uint256 deadline = IWin.getMatchBettingDeadline(1);
     vm.warp(deadline + 1);
     vm.prank(user);
    vm.expectRevert(IWinWorldCup2K26.BettingClosed.selector);
    IWin.createBet{value: 3 ether}(1, 2);

   }
   function testUserCreatesBetWithInvalidFixtureFails() public {
    IWin.addFixture("KCCA", "Vipers", "12345", 20 minutes, 100 minutes );
    vm.prank(user);
    vm.expectRevert(IWinWorldCup2K26.MatchDoesNOTExist.selector);
    IWin.createBet{value: 3 ether}(2, 2);
   }
   function testUserPlacesBetBeforeDeadlineSucceeds() public {
    IWin.addFixture("KCCA", "Vipers", "12345", 20 minutes, 100 minutes );
     vm.prank(user);
      IWin.createBet{value: 3 ether}(1, 2);
      vm.prank(user2);
      IWin.placeBet{value: 2 ether}(1, 1);
      uint256 _totalBetAmount = IWin.getTotalBetAmount(1);
      assertEq(_totalBetAmount, 5 ether);
      uint256 _Bettors = IWin.getNumBettors(1);
      assertEq(_Bettors, 2);
   }
   function testUserPlacesBetAfterDeadlineFails() public {
    IWin.addFixture("KCCA", "Vipers", "12345", 20 minutes, 100 minutes );
     vm.prank(user);
     IWin.createBet{value: 3 ether}(1, 2);
     uint256 deadline = IWin.getUserBetBettingDeadline(1);
     vm.warp(deadline + 1);
     vm.prank(user2);
     vm.expectRevert(IWinWorldCup2K26.BettingClosed.selector);
     IWin.placeBet{value: 2 ether}(1, 1);
   }
   function testUserPlacesBetOnCanceledBetFails() public {
    IWin.addFixture("KCCA", "Vipers", "12345", 20 minutes, 100 minutes );
     vm.prank(user);
     IWin.createBet{value: 3 ether}(1, 2);
     vm.prank(user2);
     IWin.placeBet{value: 2 ether}(1, 2);
     uint256 end = IWin.getMatchEnd(1);
     vm.warp(end + 1); 
     IWin.requestMatchResult(1);
     _returnReport(1, 1, 1);
     vm.prank(user3);
     vm.expectRevert(IWinWorldCup2K26.MatchCanceled.selector);
     IWin.placeBet{value: 2 ether}(1, 1);

   }
   function testUserPlacesBetAfterResultsRequestedFails() public  {
     IWin.addFixture("KCCA", "Vipers", "12345", 20 minutes, 100 minutes );
     vm.prank(user);
     IWin.createBet{value: 3 ether}(1, 2);
     uint256 end = IWin.getMatchEnd(1);
     vm.warp(end + 1); 
     IWin.requestMatchResult(1);
     vm.prank(user2);
     vm.expectRevert(IWinWorldCup2K26.ResultsRequested.selector);
     IWin.placeBet{value: 2 ether}(1, 1);
   }
   function testRequestResultAfterMatchEndSucceeds() public {
    IWin.addFixture("KCCA", "Vipers", "12345", 20 minutes, 100 minutes );
     vm.prank(user);
     IWin.createBet{value: 3 ether}(1, 2);
     uint256 end = IWin.getMatchEnd(1);
     vm.warp(end + 1); 
     IWin.requestMatchResult(1);
     assertEq(IWin.resultRequested(1), true);
   }
   function testRequestResultBeforeMatchEndFails() public {
     IWin.addFixture("KCCA", "Vipers", "12345", 20 minutes, 100 minutes );
     vm.prank(user);
     IWin.createBet{value: 3 ether}(1, 2);
     vm.expectRevert(IWinWorldCup2K26.MatchHasNotEnded.selector);
     IWin.requestMatchResult(1);
   }
   function testRequestResultTwiceFails() public {
     IWin.addFixture("KCCA", "Vipers", "12345", 20 minutes, 100 minutes );
     vm.prank(user);
     IWin.createBet{value: 3 ether}(1, 2);
     uint256 end = IWin.getMatchEnd(1);
     vm.warp(end + 1); 
     IWin.requestMatchResult(1);
     vm.expectRevert(IWinWorldCup2K26.ResultsRequested.selector);
     IWin.requestMatchResult(1);
   }
   function testFinalizeMatchResultCallFromCRESucceeds() public {
     IWin.addFixture("KCCA", "Vipers", "12345", 20 minutes, 100 minutes );
     vm.prank(user);
     IWin.createBet{value: 3 ether}(1, 2);
     uint256 end = IWin.getMatchEnd(1);
     vm.warp(end + 1); 
     IWin.requestMatchResult(1);
      _returnReport(1, 2, 1);
     assertEq(IWin.getWinner(1), 2);
   }
   function testFinalizeMatchResultCallNotFromCREFails() public {
    IWin.addFixture("KCCA", "Vipers", "12345", 20 minutes, 100 minutes );
     vm.startPrank(user);
     IWin.createBet{value: 3 ether}(1, 2);
     uint256 end = IWin.getMatchEnd(1);
     vm.warp(end + 1); 
     IWin.requestMatchResult(1);
     vm.expectRevert();
     bytes memory metadata = abi.encodePacked(
        expectedWorkflowId,
        expectedWorkflowName,
        expectedWorkflowOwner
    );

    bytes memory report = abi.encode(
        uint256(1),
        uint8(3),
        chainSelector,
        uint(1)
    );

    IWin.onReport(metadata, report);

   }
   function testFinalizeMatchResultCalledTwiceFromCREFails() public {
      IWin.addFixture("KCCA", "Vipers", "12345", 20 minutes, 100 minutes );
     vm.prank(user);
     IWin.createBet{value: 3 ether}(1, 2);
     uint256 end = IWin.getMatchEnd(1);
     vm.warp(end + 1); 
     IWin.requestMatchResult(1);
    _returnReport(1, 2, 1);
    vm.expectRevert(IWinWorldCup2K26.ReplayAttack.selector);
    _returnReport(1, 2, 1);

   }
   function testFinalizeMatchResultCalledFromCREWithInvalidOutComeFails() public {
    IWin.addFixture("KCCA", "Vipers", "12345", 20 minutes, 100 minutes );
     vm.prank(user);
     IWin.createBet{value: 3 ether}(1, 2);
     uint256 end = IWin.getMatchEnd(1);
     vm.warp(end + 1); 
     IWin.requestMatchResult(1);
     vm.expectRevert(IWinWorldCup2K26.InvalidWinner.selector);
     _returnReport(1, 4, 1);
   }
   function testWinnerClaimsWinnings() public {
    IWin.addFixture("KCCA", "Vipers", "12345", 20 minutes, 100 minutes );
     vm.prank(user);
     IWin.createBet{value: 3 ether}(1, 2);
     vm.prank(user2);
     IWin.placeBet{value: 2 ether}(1, 3);
     uint256 end = IWin.getMatchEnd(1);
     vm.warp(end + 1); 
     IWin.requestMatchResult(1);
     _returnReport(1, 3, 1);
     uint256 balanceBefore = user2.balance;
     vm.prank(user2);
     IWin.claimWinnings(1);
     assertEq(
     user2.balance,
     balanceBefore + 4.5 ether
     );
   }
   function testLoserCanNotClaimsWinnings() public {
    IWin.addFixture("KCCA", "Vipers", "12345", 20 minutes, 100 minutes );
     vm.prank(user);
     IWin.createBet{value: 3 ether}(1, 2);
     vm.prank(user2);
     IWin.placeBet{value: 2 ether}(1, 3);
     uint256 end = IWin.getMatchEnd(1);
     vm.warp(end + 1); 
     IWin.requestMatchResult(1);
    _returnReport(1, 3, 1);
     vm.prank(user);
     vm.expectRevert(IWinWorldCup2K26.YouDidnotWin.selector);
     IWin.claimWinnings(1);
   }
   function testDoubleClaimFails() public {
    IWin.addFixture("KCCA", "Vipers", "12345", 20 minutes, 100 minutes );
    vm.prank(user);
     IWin.createBet{value: 3 ether}(1, 2);
     vm.prank(user2);
     IWin.placeBet{value: 2 ether}(1, 3);
     uint256 end = IWin.getMatchEnd(1);
     vm.warp(end + 1); 
     IWin.requestMatchResult(1);
     _returnReport(1, 3, 1);
     vm.startPrank(user2);
     IWin.claimWinnings(1);
     vm.expectRevert(IWinWorldCup2K26.AlreadyClaimed.selector);
     IWin.claimWinnings(1);
     vm.stopPrank();
   }
   function claimWinningsOnCanceledBetFails() public {
    IWin.addFixture("KCCA", "Vipers", "12345", 20 minutes, 100 minutes );
    vm.prank(user);
     IWin.createBet{value: 3 ether}(1, 3);
     vm.prank(user2);
     IWin.placeBet{value: 2 ether}(1, 3);
     uint256 end = IWin.getMatchEnd(1);
     vm.warp(end + 1); 
     IWin.requestMatchResult(1);
     _returnReport(1, 3, 1);
     vm.prank(user);
     vm.expectRevert(IWinWorldCup2K26.MatchCanceled.selector);
     IWin.claimWinnings(1);

   }
   function testRefundOnCanceledBetSucceeds() public {
    IWin.addFixture("KCCA", "Vipers", "12345", 20 minutes, 100 minutes );
    vm.prank(user);
     IWin.createBet{value: 3 ether}(1, 3);
     vm.prank(user2);
      uint256 balanceBefore = user2.balance;
     IWin.placeBet{value: 2 ether}(1, 3);
     uint256 end = IWin.getMatchEnd(1);
     vm.warp(end + 1); 
     IWin.requestMatchResult(1);
      _returnReport(1, 3, 1);
     vm.prank(user2);
     IWin.refund(1);
     uint256 balanceAfter = user2.balance;
     assertEq(balanceAfter, balanceBefore );
   }
   function testRefundUserTwiceOnCanceledBetFails() public {
    IWin.addFixture("KCCA", "Vipers", "12345", 20 minutes, 100 minutes );
    vm.prank(user);
     IWin.createBet{value: 3 ether}(1, 3);
     vm.prank(user2);
     IWin.placeBet{value: 2 ether}(1, 3);
     uint256 end = IWin.getMatchEnd(1);
     vm.warp(end + 1); 
     IWin.requestMatchResult(1);
      _returnReport(1, 3, 1);
     vm.startPrank(user);
     IWin.refund(1);
     vm.expectRevert(IWinWorldCup2K26.AlreadyClaimed.selector);
     IWin.refund(1);
     vm.stopPrank();
   }
   function testRefundUserWhenBetNotCanceledFails() public {
    IWin.addFixture("KCCA", "Vipers", "12345", 20 minutes, 100 minutes );
    vm.prank(user);
     IWin.createBet{value: 3 ether}(1, 3);
     vm.prank(user2);
     IWin.placeBet{value: 2 ether}(1, 1);
     uint256 end = IWin.getMatchEnd(1);
     vm.warp(end + 1); 
     IWin.requestMatchResult(1);
      _returnReport(1, 3, 1);
     vm.prank(user);
     vm.expectRevert(IWinWorldCup2K26.MatchNotCanceled.selector);
     IWin.refund(1); 
   }
   function testProtocolFeesAccumulateCorrectly() public {
     IWin.addFixture("KCCA", "Vipers", "12345", 20 minutes, 100 minutes );
    vm.prank(user);
     IWin.createBet{value: 3 ether}(1, 3);
     vm.prank(user2);
     IWin.placeBet{value: 2 ether}(1, 1);
     uint256 end = IWin.getMatchEnd(1);
     vm.warp(end + 1); 
     IWin.requestMatchResult(1);
      _returnReport(1, 3, 1);
     uint256 feesBefore = IWin.getProtocolFees();
     vm.prank(user);
     IWin.claimWinnings(1);
     uint256 feesAfter = IWin.getProtocolFees();
     assertEq(feesAfter, feesBefore + 0.5 ether);
   }
   function testOwnerWithdrawsProtocolFees() public {
     IWin.addFixture("KCCA", "Vipers", "12345", 20 minutes, 100 minutes );
    vm.prank(user);
     IWin.createBet{value: 3 ether}(1, 3);
     vm.prank(user2);
     IWin.placeBet{value: 2 ether}(1, 1);
     uint256 end = IWin.getMatchEnd(1);
     vm.warp(end + 1); 
     IWin.requestMatchResult(1);
      _returnReport(1, 3, 1);
     uint256 balanceBefore = address(this).balance;
     vm.prank(user);
     IWin.claimWinnings(1);
     IWin.withdrawProtocolFees();
     uint256 balanceAfter = address(this).balance;
     assertEq(balanceAfter, balanceBefore + 0.5 ether);
   }
   function testNotContractCreatorWithdrawsFeesFails() public {
  IWin.addFixture("KCCA", "Vipers", "12345", 20 minutes, 100 minutes );
    vm.prank(user);
     IWin.createBet{value: 3 ether}(1, 3);
     vm.prank(user2);
     IWin.placeBet{value: 2 ether}(1, 1);
     uint256 end = IWin.getMatchEnd(1);
     vm.warp(end + 1); 
     IWin.requestMatchResult(1);
     _returnReport(1, 3, 1);
     vm.startPrank(user);
     IWin.claimWinnings(1);
     vm.expectRevert();
     IWin.withdrawProtocolFees();
   }
   function testBetCreatorExtendsBettingDeadline() public {
    IWin.addFixture("KCCA", "Vipers", "12345", 20 minutes, 100 minutes );
    vm.startPrank(user);
     IWin.createBet{value: 3 ether}(1, 3);
     IWin. extendBettingDeadline(1, 30 minutes);
     uint256 deadlineAfter = IWin.getUserBetBettingDeadline(1);
     assertEq(deadlineAfter, block.timestamp + 30 minutes);
     vm.stopPrank();

   }
   function testNonCreatorCannotExtendBettingDeadline() public {
    IWin.addFixture("KCCA", "Vipers", "12345", 20 minutes, 100 minutes );
    vm.prank(user);
     IWin.createBet{value: 3 ether}(1, 3);
     vm.prank(user2);
     vm.expectRevert(IWinWorldCup2K26.Unauthorized.selector);
      IWin. extendBettingDeadline(1, 30 minutes);
   }
   function testCreatorCannotExtendBettingDeadlineAfterAnotherUserPlacesBet() public {
    IWin.addFixture("KCCA", "Vipers", "12345", 20 minutes, 100 minutes );
    vm.prank(user);
     IWin.createBet{value: 3 ether}(1, 3);
     vm.prank(user2);
     IWin.placeBet{value: 2 ether}(1, 2);
     vm.prank(user);
     vm.expectRevert(IWinWorldCup2K26.PermissionDenied.selector);
      IWin. extendBettingDeadline(1, 30 minutes);
   }
   function testBetCreatorCannotExtendBettingDeadlineAfterMatchEnds() public {
      IWin.addFixture("KCCA", "Vipers", "12345", 20 minutes, 100 minutes );
      uint256 _matchEnd = IWin.getMatchEnd(1);
    vm.startPrank(user);
     IWin.createBet{value: 3 ether}(1, 3);
     vm.warp(_matchEnd + 1);
     IWin.requestMatchResult(1);
      vm.expectRevert(IWinWorldCup2K26.BettingClosed.selector);
      IWin. extendBettingDeadline(1, 30 minutes);
    vm.stopPrank(); 
   }
  function testEventBetCreatedEmits() public {
    IWin.addFixture("KCCA", "Vipers", "12345", 20 minutes, 100 minutes );
    vm.startPrank(user);
    vm.expectEmit(true, true, false, true);
    emit IWinWorldCup2K26.BetCreated(1, user, 3 ether);
     IWin.createBet{value: 3 ether}(1, 3);
     vm.stopPrank();
  }
  function testEventBetPlacedEmits() public {
    IWin.addFixture("KCCA", "Vipers", "12345", 20 minutes, 100 minutes );
    vm.prank(user);
    IWin.createBet{value: 3 ether}(1, 3);
    vm.expectEmit(true, true, false, true);
    emit IWinWorldCup2K26.BetPlaced(1, user2, 5 ether);
    vm.prank(user2);
    IWin.placeBet{value: 5 ether}(1, 2);

  }
  function testEventResultRequestedForCREEmits() public {
     IWin.addFixture("KCCA", "Vipers", "12345", 20 minutes, 100 minutes );
    vm.prank(user);
    IWin.createBet{value: 3 ether}(1, 3);
    vm.startPrank(user2);
    IWin.placeBet{value: 5 ether}(1, 2);
    uint256 _matchEnd = IWin.getMatchEnd(1);
    vm.warp(_matchEnd + 1);
    vm.expectEmit(true, true, false, true);
    emit IWinWorldCup2K26.ResultRequestedForCRE(1, 1, "12345");
    IWin.requestMatchResult(1);
    vm.stopPrank();
  }
  function testEventResultReceivedEmits() public {
     IWin.addFixture("KCCA", "Vipers", "12345", 20 minutes, 100 minutes );
    vm.prank(user);
    IWin.createBet{value: 3 ether}(1, 3);
    vm.startPrank(user2);
    IWin.placeBet{value: 5 ether}(1, 2);
    uint256 _matchEnd = IWin.getMatchEnd(1);
    vm.warp(_matchEnd + 1);
    IWin.requestMatchResult(1);
    vm.stopPrank();
    vm.expectEmit(true, true, false, true);
     emit IWinWorldCup2K26.ResultReceived(1, 3);
    _returnReport(1, 3, 1);
    
     
  }
  function testEventClaimedWinningsEmits() public {
    IWin.addFixture("KCCA", "Vipers", "12345", 20 minutes, 100 minutes );
    vm.prank(user);
    IWin.createBet{value: 3 ether}(1, 3);
    vm.startPrank(user2);
    IWin.placeBet{value: 5 ether}(1, 2);
    uint256 _matchEnd = IWin.getMatchEnd(1);
    vm.warp(_matchEnd + 1);
    IWin.requestMatchResult(1);
    vm.stopPrank();
   _returnReport(1, 3, 1);
     vm.expectEmit(true, true, false, true);
     emit IWinWorldCup2K26.ClaimedWinnings(1, user, 7.2 ether);
     vm.prank(user);
     IWin.claimWinnings(1);
  }
  function testEventRefundedEmits() public {
     IWin.addFixture("KCCA", "Vipers", "12345", 20 minutes, 100 minutes );
    vm.prank(user);
    IWin.createBet{value: 3 ether}(1, 3);
    vm.startPrank(user2);
    IWin.placeBet{value: 5 ether}(1, 2);
    uint256 _matchEnd = IWin.getMatchEnd(1);
    vm.warp(_matchEnd + 1);
    IWin.requestMatchResult(1);
    vm.stopPrank();
    _returnReport(1, 1, 1);
     vm.expectEmit(true, true, false, true);
     emit IWinWorldCup2K26.Refunded(1, user, 3 ether);
     vm.prank(user);
     IWin.refund(1);
  }
  function testEventBettingDeadlineExtendedEmits() public {
      IWin.addFixture("KCCA", "Vipers", "12345", 20 minutes, 100 minutes );
    vm.startPrank(user);
     IWin.createBet{value: 3 ether}(1, 3);
     vm.expectEmit(true, true, false, true);
     emit IWinWorldCup2K26.BettingDeadlineExtended(1, user, block.timestamp + 30 minutes);
     IWin. extendBettingDeadline(1, 30 minutes);
     vm.stopPrank();
  }
  function testProtocolFeesWithdrawalResetsFeesToZero() public {
    IWin.addFixture("KCCA", "Vipers", "12345", 20 minutes, 100 minutes );
    vm.prank(user);
     IWin.createBet{value: 3 ether}(1, 2);
     vm.prank(user2);
     IWin.placeBet{value: 2 ether}(1, 3);
     uint256 end = IWin.getMatchEnd(1);
     vm.warp(end + 1); 
     IWin.requestMatchResult(1);
     _returnReport(1, 3, 1);
     vm.prank(user2);
     IWin.claimWinnings(1);
     IWin.withdrawProtocolFees();
     uint256 feesAfter = IWin.getProtocolFees();
     assertEq(feesAfter, 0);

  }
  function testProtocolFeesWithdrawOfZeroFails() public {
    vm.expectRevert(IWinWorldCup2K26.NoAmountFound.selector);
    IWin.withdrawProtocolFees();
  }
  function testFuzzCreateBetWithArbitraryAmount(uint256 amount) public {
    amount = bound(amount, 1 wei, 100 ether);

    IWin.addFixture("KCCA", "Vipers", "12345", 20 minutes, 100 minutes);

    vm.deal(user, amount);

    vm.prank(user);
    IWin.createBet{value: amount}(1, 2);

    assertEq(IWin.getTotalBetAmount(1), amount);
}
function testFuzzMultipleBettors(uint256 amount1, uint256 amount2, uint256 amount3) public {
    amount1 = bound(amount1, 1 wei, 100 ether);
    amount2 = bound(amount2, 1 wei, 100 ether);
    amount3 = bound(amount3, 1 wei, 100 ether);

    IWin.addFixture("KCCA", "Vipers", "12345", 20 minutes, 100 minutes);

    vm.deal(user, amount1);
    vm.prank(user);
    IWin.createBet{value: amount1}(1, 1);

    vm.deal(user2, amount2);
    vm.prank(user2);
    IWin.placeBet{value: amount2}(1, 2);

    vm.deal(user3, amount3);
    vm.prank(user3);
    IWin.placeBet{value: amount3}(1, 3);

    assertEq(IWin.getTotalBetAmount(1), amount1 + amount2 + amount3);
    assertEq(IWin.getNumBettors(1), 3);
}
function testFuzzPayoutInvariant(uint256 winnerAmount, uint256 loserAmount) public {
    winnerAmount = bound(winnerAmount, 1 wei, 100 ether);
    loserAmount = bound(loserAmount, 1 wei, 100 ether);

    IWin.addFixture("KCCA", "Vipers", "12345", 20 minutes, 100 minutes);

    vm.deal(user, winnerAmount);
    vm.prank(user);
    IWin.createBet{value: winnerAmount}(1, 1);

    vm.deal(user2, loserAmount);
    vm.prank(user2);
    IWin.placeBet{value: loserAmount}(1, 2);

    uint256 totalPool = winnerAmount + loserAmount;

    uint256 end = IWin.getMatchEnd(1);
    vm.warp(end + 1);

    IWin.requestMatchResult(1);

    _returnReport(1, 1, 1);

    uint256 balanceBefore = user.balance;

    vm.prank(user);
    IWin.claimWinnings(1);

    uint256 payout = user.balance - balanceBefore;
    uint256 protocolFee = IWin.getProtocolFees();

    assertEq(payout + protocolFee, totalPool);
}
function testWrongWorkflowIdFails() public {
 
      bytes memory metadata = abi.encodePacked(
        bytes32("wrong workflow Id"),
        expectedWorkflowName,
        expectedWorkflowOwner
    );

    bytes memory report = abi.encode(
        uint256(1),
        uint8(2),
        chainSelector,
        uint256(1)
    );

    
     vm.expectRevert(abi.encodeWithSelector(ReceiverTemplate.InvalidWorkflowId.selector, bytes32("wrong workflow Id"), IWin.getExpectedWorkflowId()));
    vm.prank(keystoneForwarder);
    IWin.onReport(metadata, report);
}
function testWrongWorkflowOwnerFails() public {
  
      bytes memory metadata = abi.encodePacked(
        expectedWorkflowId,
        expectedWorkflowName,
        address(100)
    );

    bytes memory report = abi.encode(
        uint256(1),
        uint8(2),
        chainSelector,
        uint256(1)
    );

     vm.expectRevert(abi.encodeWithSelector(ReceiverTemplate.InvalidAuthor.selector, address(100), IWin.getExpectedAuthor()));
    vm.prank(keystoneForwarder);
    IWin.onReport(metadata, report);
}
function testWrongWorkflowNameFails() public {
    
      bytes memory metadata = abi.encodePacked(
        expectedWorkflowId,
        bytes10("wrong"),
        expectedWorkflowOwner
    );

    bytes memory report = abi.encode(
        uint256(1),
        uint8(2),
        chainSelector,
        uint256(1)
    );

    vm.expectRevert(abi.encodeWithSelector(ReceiverTemplate.InvalidWorkflowName.selector, bytes10("wrong"), IWin.getExpectedWorkflowName()));
    vm.prank(keystoneForwarder);
    IWin.onReport(metadata, report);
}
function testWrongChainSelectorFails() public { 
  IWin.addFixture("KCCA", "Vipers", "12345", 20 minutes, 100 minutes);
  vm.prank(user);
     IWin.createBet{value: 3 ether}(1, 2);
     uint256 _matchEnd = IWin.getMatchEnd(1);
    vm.warp(_matchEnd + 1);
    IWin.requestMatchResult(1);
   bytes memory metadata = abi.encodePacked(
        expectedWorkflowId,
        expectedWorkflowName,
        expectedWorkflowOwner
    );

    bytes memory report = abi.encode(
        uint256(1),
        uint8(1),
        uint64(67589),
        uint256(1)
    );
    vm.expectRevert(IWinWorldCup2K26.InvalidChain.selector);
    vm.prank(keystoneForwarder);
    IWin.onReport(metadata, report);
}
 function testInvalidMetadataLengthFails() public {
  bytes memory metadata = abi.encodePacked(
        expectedWorkflowId,
        expectedWorkflowName,
        expectedWorkflowOwner,
        bytes4("haha")
    );

    bytes memory report = abi.encode(
        uint256(1),
        uint8(1),
        chainSelector,
        uint256(1)
    );
    vm.expectRevert(ReceiverTemplate.InvalidMetadata.selector);
    vm.prank(keystoneForwarder);
    IWin.onReport(metadata, report);
 }
 function testForwarderCallNotFromKeystoneFails() public {
  bytes memory metadata = abi.encodePacked(
        expectedWorkflowId,
        expectedWorkflowName,
        expectedWorkflowOwner
    );

    bytes memory report = abi.encode(
        uint256(1),
        uint8(1),
        chainSelector,
        uint256(1)
    );
    vm.expectRevert(abi.encodeWithSelector(ReceiverTemplate.InvalidSender.selector, user, keystoneForwarder));
    vm.prank(user);
    IWin.onReport(metadata, report);
 }
}

 
    
