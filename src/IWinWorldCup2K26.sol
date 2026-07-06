//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {ReceiverTemplate} from "./ReceiverTemplate.sol";


contract IWinWorldCup2K26 is ReentrancyGuard, ReceiverTemplate {
    struct Bet {
        uint256 betId;
        uint256 totalPool;
        address creator;
        uint256 numBettors;
        uint8 winner; //0 = undecided, 1 = A wins, 2 = B wins, 3 = Draw
        mapping(address => uint256) betsOnA;
        mapping(address => uint256) betsOnB;
        mapping(address => uint256) betsOnDraw;
        uint256 totalA;
        uint256 totalB;
        uint256 totalDraw;
        bool bettingClosed;
        bool resultRequested;
        bool canceled;
        mapping(address => bool) claimed;
        uint256 fixtureId;
        bool exists;
        uint256 bettingDeadline;
    }

    struct Fixture {
        uint256 fixtureId;
        string teamA;
        string teamB;
        string externalApiId;
        uint256 bettingDeadline;
        uint256 matchEnd;
        bool exists;
    }
    uint256 public protocolFee;
    uint256 public feeBasisPoints = 1000; // 10%
    uint64 public immutable chainSelector;

    uint256 public constant RESULT_TIMEOUT = 2 hours;
    uint256 public userBetCount;
    uint256 public fixtureCount;
    error InvalidWinner();
    error ResultAlreadySet();

    mapping(uint256 => Bet) public userBets;
    mapping(uint256 => mapping(uint256 => bool)) public usedNonce;
    mapping(uint256 => Fixture) public fixtures;
    ///Amount must be greater than zero
    error AmountNotEnough();
    ///You must fill values for the fields.
    error FieldsRequired();
    ///only 1 for a win by TeamA , 2 for a win by TeamB and 3 for a Draw are allowed as outcome values.
    error InvalidOutcomeValues();
    ///You too late.
    error BettingClosed();
    error MatchHasEnded();
    ///Check Refund.
    error CanceledMatch();
    ///Results already requested;
    error ResultsRequested();
    error MatchHasNotEnded();
    ///Betting has not yet ended.
    error BettingStillOpen();
    ///Check MatchId and try again.
    error MatchDoesNOTExist();
    ///Request results first.
    error ResultsNotReturned();
    ///You have already claimed winnings.
    error AlreadyClaimed();
    error YouDidnotWin();
    ///Match not canceled claim winnings.
    error MatchNotCanceled();
    ///You are not allowed to make this call.
    error Unauthorized();
    ///Number of bettors exceeds 1.
    error PermissionDenied();
    error NoBetFound();
    error InvalidWinnerReturned();
    error NoAmountFound();
    error RefundFailed();
    error PaymentFailed();
    error ContractFeesPaymentFailed();
    ///Match duration is less or equal to betting deadline duration.
    error Disallowed();
    error BetDoesNOTExist();
    error BettingNotClosed();
    error InvalidChain();
    error ReplayAttack();
    error GracePeriodNotElapsed();

    event BetCreated(uint256 indexed betId, address indexed creator, uint256 escrowedAmount);
    event BetPlaced(uint256 indexed betId, address indexed bettor, uint256 amount);

    event ResultReceived(uint256 indexed betId, uint8 winner);
    event ClaimedWinnings(uint256 indexed betId, address indexed bettor, uint256 amount);
    event Refunded(uint256 indexed betId, address indexed user, uint256 amount);
    event BettingDeadlineExtended(uint256 indexed betId, address indexed creator, uint256 newBettingDeadline);
    event FixtureAdded(
        uint256 indexed fixtureId, string indexed teamA, string indexed teamB, uint256 bettingDeadline, uint256 matchEnd
    );
    event ResultRequestedForCRE(uint256 indexed betId, uint256 indexed fixtureId, string externalApiId);
    event MatchCanceled(uint256 indexed betId);

constructor(
    address _keystoneForwarder,
    bytes32 _expectedWorkflowId,
    bytes10 _expectedWorkflowName,
    address _expectedWorkflowOwner,
    uint64 _chainSelector
)
    ReceiverTemplate(
        _keystoneForwarder,
        _expectedWorkflowId,
        _expectedWorkflowName,
        _expectedWorkflowOwner
    )
{
    require(_chainSelector != 0, FieldsRequired());
    chainSelector = _chainSelector;
}

    function addFixture(
        string memory _teamA,
        string memory _teamB,
        string memory _externalAPI_ID,
        uint256 bettingDuration,
        uint256 matchDuration
    ) external onlyOwner {
        require(
            bytes(_teamA).length > 0 && bytes(_teamB).length > 0 && bytes(_externalAPI_ID).length > 0, FieldsRequired()
        );
        require(matchDuration > bettingDuration, Disallowed());
        fixtureCount++;
        Fixture storage f = fixtures[fixtureCount];
        f.fixtureId = fixtureCount;
        f.teamA = _teamA;
        f.teamB = _teamB;
        f.externalApiId = _externalAPI_ID;
        f.bettingDeadline = (block.timestamp + bettingDuration);
        f.matchEnd = (block.timestamp + matchDuration);
        f.exists = true;
        emit FixtureAdded(f.fixtureId, f.teamA, f.teamB, f.bettingDeadline, f.matchEnd);
    }

    function createBet(uint256 _fixtureId, uint8 outcome) public payable {
        require(msg.value > 0, AmountNotEnough());
        require(_fixtureId > 0, FieldsRequired());
        require(outcome >= 1 && outcome <= 3, InvalidOutcomeValues());
        require(fixtures[_fixtureId].exists, MatchDoesNOTExist());
        require(block.timestamp < fixtures[_fixtureId].bettingDeadline, BettingClosed());
        userBetCount++;
        Bet storage m = userBets[userBetCount];
        m.exists = true;
        m.creator = msg.sender;
        m.betId = userBetCount;
        m.fixtureId = _fixtureId;
        m.bettingDeadline = fixtures[_fixtureId].bettingDeadline;
        m.numBettors += (m.betsOnA[msg.sender] == 0 && m.betsOnB[msg.sender] == 0 && m.betsOnDraw[msg.sender] == 0)
            ? 1
            : 0;
        bet(m.betId, outcome, msg.value, msg.sender);
        emit BetCreated(m.betId, msg.sender, msg.value);
    }

    function bet(uint256 _betId, uint8 outcome, uint256 amount, address bettor) internal {
        Bet storage m = userBets[_betId];
        require(m.exists, BetDoesNOTExist());
        m.totalPool += amount;
        if (outcome == 1) {
            m.betsOnA[bettor] += amount;
            m.totalA += amount;
        } else if (outcome == 2) {
            m.betsOnB[bettor] += amount;
            m.totalB += amount;
        } else {
            m.betsOnDraw[bettor] += amount;
            m.totalDraw += amount;
        }
    }

    function placeBet(uint256 _betId, uint8 outcome) external payable {
        require(msg.value > 0, AmountNotEnough());
        require(_betId > 0 && outcome > 0, FieldsRequired());
        require(outcome >= 1 && outcome <= 3, InvalidOutcomeValues());
        Bet storage m = userBets[_betId];
        require(m.exists, BetDoesNOTExist());
        require(!m.canceled, CanceledMatch());
        require(!m.resultRequested, ResultsRequested());
        require(block.timestamp < m.bettingDeadline, BettingClosed());
        require(!m.bettingClosed, BettingClosed());
        m.numBettors += (m.betsOnA[msg.sender] == 0 && m.betsOnB[msg.sender] == 0 && m.betsOnDraw[msg.sender] == 0)
            ? 1
            : 0;
        bet(_betId, outcome, msg.value, msg.sender);
        emit BetPlaced(_betId, msg.sender, msg.value);
    }

    function requestMatchResult(uint256 _betId) external {
        require(_betId > 0, FieldsRequired());

        Bet storage m = userBets[_betId];
        require(m.exists, BetDoesNOTExist());
        require(!m.resultRequested, ResultsRequested());
        require(!m.bettingClosed, BettingClosed());
        require(!m.canceled, CanceledMatch());
        Fixture storage f = fixtures[m.fixtureId];
        require(f.exists, MatchDoesNOTExist());
        require(block.timestamp > f.matchEnd, MatchHasNotEnded());

        m.bettingClosed = true;
        m.resultRequested = true;

        emit ResultRequestedForCRE(_betId, m.fixtureId, f.externalApiId);
    }
      function _processReport(bytes calldata report) internal override {
    (
    uint256 betId,
    uint8 winner,
    uint64 selector,
    uint256 nonce
) = abi.decode(
        report,
        (
            uint256,
            uint8,
            uint64,
            uint256
        )
    );
    require(
    nonce > 0,
    FieldsRequired()
);

require(selector == chainSelector, InvalidChain());

require(!usedNonce[betId][nonce], ReplayAttack());
usedNonce[betId][nonce] = true;

finalizeMatchResult(
    betId,
    winner
);
}
    function finalizeMatchResult(uint256 _betId, uint8 winner) internal  {
        require(_betId > 0, FieldsRequired());
        require(winner >= 1 && winner <= 3, InvalidWinner());

        Bet storage m = userBets[_betId];
        require(m.exists, BetDoesNOTExist());
        require(m.winner == 0, ResultAlreadySet());
        require(m.bettingClosed, BettingNotClosed());
        require(m.resultRequested, ResultsNotReturned());
        m.winner = winner;

        uint256 totalWinnerPool;
        uint256 totalLoserPool;

        if (winner == 1) {
            totalWinnerPool = m.totalA;
            totalLoserPool = m.totalB + m.totalDraw;
        } else if (winner == 2) {
            totalWinnerPool = m.totalB;
            totalLoserPool = m.totalA + m.totalDraw;
        } else {
            totalWinnerPool = m.totalDraw;
            totalLoserPool = m.totalA + m.totalB;
        }

        if (totalWinnerPool == 0 || totalLoserPool == 0) {
            m.canceled = true;
            emit MatchCanceled(_betId);
        }

        emit ResultReceived(_betId, winner);
    }

    function claimWinnings(uint256 _betId) external nonReentrant {
        require(_betId > 0, FieldsRequired());
        Bet storage m = userBets[_betId];
        require(m.exists, BetDoesNOTExist());
        require(m.bettingClosed, BettingNotClosed());
        require(m.winner == 1 || m.winner == 2 || m.winner == 3, ResultsNotReturned());
        require(!m.canceled, CanceledMatch());
        require(!m.claimed[msg.sender], AlreadyClaimed());
        uint256 betAmount;
        betAmount = (m.winner == 1)
            ? m.betsOnA[msg.sender]
            : (m.winner == 2) ? m.betsOnB[msg.sender] : m.betsOnDraw[msg.sender];
        require(betAmount > 0, YouDidnotWin());
        uint256 totalWinnerPool;
        totalWinnerPool = (m.winner == 1) ? m.totalA : (m.winner == 2) ? m.totalB : m.totalDraw;
        uint256 UserAmount = (betAmount * m.totalPool) / totalWinnerPool;
        uint256 contractFees = (feeBasisPoints * UserAmount) / 10000;
        uint256 payOutAmount = UserAmount - contractFees;
        protocolFee += contractFees;
        m.claimed[msg.sender] = true;
        (bool success,) = payable(msg.sender).call{value: payOutAmount}("");
        require(success, PaymentFailed());
        emit ClaimedWinnings(_betId, msg.sender, payOutAmount);
    }

    function refund(uint256 _betId) external nonReentrant {
        require(_betId > 0, FieldsRequired());
        Bet storage m = userBets[_betId];
        require(m.exists, BetDoesNOTExist());
        require(m.bettingClosed, BettingNotClosed());
        require(m.canceled, MatchNotCanceled());
        require(!m.claimed[msg.sender], AlreadyClaimed());
        uint256 refundAmount = m.betsOnA[msg.sender] + m.betsOnB[msg.sender] + m.betsOnDraw[msg.sender];
        if (refundAmount == 0) revert NoAmountFound();
        m.claimed[msg.sender] = true;
        (bool success,) = payable(msg.sender).call{value: refundAmount}("");
        require(success, RefundFailed());
        emit Refunded(_betId, msg.sender, refundAmount);
    }

    function withdrawProtocolFees() external onlyOwner nonReentrant {
        require(protocolFee > 0, NoAmountFound());
        uint256 amountToWithdraw = protocolFee;
        protocolFee = 0;
        (bool success,) = payable(owner()).call{value: amountToWithdraw}("");
        require(success, ContractFeesPaymentFailed());
    }
    

function cancelIfResultUnavailable(uint256 betId) external {
    require(betId > 0, FieldsRequired());
    Bet storage b = userBets[betId];
    require(b.exists, BetDoesNOTExist());
    Fixture storage f = fixtures[b.fixtureId];

    require(b.winner == 0, ResultAlreadySet());

    require(
        block.timestamp > f.matchEnd + RESULT_TIMEOUT,
        GracePeriodNotElapsed()
    );

    b.canceled = true;

    emit MatchCanceled(betId);
}

    function getProtocolFees() external view  returns (uint256 _protocolFee) {
        _protocolFee = protocolFee;
    }

    function updateFeeBasisPoints(uint256 _newFeeBasisPoints) external onlyOwner {
        require(_newFeeBasisPoints > 0, FieldsRequired());
       require(
    _newFeeBasisPoints <= 2000,
    Disallowed()
);
        feeBasisPoints = _newFeeBasisPoints;
    }

    function extendBettingDeadline(uint256 _betId, uint256 duration) external {
        require(_betId > 0, FieldsRequired());

        Bet storage m = userBets[_betId];
        require(m.exists, BetDoesNOTExist());
        Fixture storage f = fixtures[m.fixtureId];
        require(msg.sender == m.creator, Unauthorized());
        require(!m.bettingClosed, BettingClosed());
        require(m.numBettors == 1, PermissionDenied());
        uint256 newBettingDeadline = block.timestamp + duration;
        require(newBettingDeadline < f.matchEnd, Disallowed());
        m.bettingDeadline = newBettingDeadline;
        emit BettingDeadlineExtended(_betId, msg.sender, newBettingDeadline);
    }

    function getFixtureTeams(uint256 _fixtureId) external view returns (string memory A, string memory B) {
        require(_fixtureId > 0, FieldsRequired());
        Fixture storage m = fixtures[_fixtureId];
        require(m.exists, MatchDoesNOTExist());
        return (m.teamA, m.teamB);
    }
    function getFixtureCount() external view returns (uint256 _fixtures) {
        return fixtureCount;
    }
    function getBetCount() external view returns (uint256 _bets) {
        return userBetCount;
    }

    function getMatchBettingDeadline(uint256 _fixtureId) external view returns (uint256 _bettingDeadline) {
        require(_fixtureId > 0, FieldsRequired());
        Fixture storage m = fixtures[_fixtureId];
        require(m.exists, MatchDoesNOTExist());
        return m.bettingDeadline;
    }
    function getUserBetBettingDeadline(uint256 _betId) external view returns (uint256 _Deadline) {
         require(_betId > 0, FieldsRequired());
         Bet storage m = userBets[_betId];
         return m.bettingDeadline;
    }

    function getMatchEnd(uint256 _fixtureId) external view returns (uint256 _matchEnd) {
        require(_fixtureId > 0, FieldsRequired());
        Fixture storage m = fixtures[_fixtureId];
        require(m.exists, MatchDoesNOTExist());
        return m.matchEnd;
    }

    function getWinner(uint256 _betId) external view returns (uint8 _winner) {
        require(_betId > 0, FieldsRequired());
        Bet storage m = userBets[_betId];
        require(m.exists, BetDoesNOTExist());
        return m.winner;
    }

    function getTotalBetAmount(uint256 _betId) external view returns (uint256 _totalPool) {
        require(_betId > 0, FieldsRequired());
        Bet storage m = userBets[_betId];
        require(m.exists, BetDoesNOTExist());
        return m.totalPool;
    }

    function getUserInfo(uint256 _betId) external view returns (bool betsOnA, bool betsOnB, bool betsOnDraw) {
        require(_betId > 0, FieldsRequired());
        Bet storage m = userBets[_betId];
        require(m.exists, BetDoesNOTExist());
        if (m.betsOnA[msg.sender] > 0) {
            betsOnA = true;
        } else if (m.betsOnB[msg.sender] > 0) {
            betsOnB = true;
        } else {
            betsOnDraw = (m.betsOnDraw[msg.sender] > 0) ? true : false;
        }
        require(betsOnA || betsOnB || betsOnDraw, NoBetFound());
    }

    function getUserBetAmount(uint256 _betId)
        external
        view
        returns (uint256 amountOnA, uint256 amountOnB, uint256 amountOnDraw)
    {
        require(_betId > 0, FieldsRequired());
        Bet storage m = userBets[_betId];
        require(m.exists, BetDoesNOTExist());
        amountOnA = m.betsOnA[msg.sender];
        amountOnB = m.betsOnB[msg.sender];
        amountOnDraw = m.betsOnDraw[msg.sender];
        require(amountOnA > 0 || amountOnB > 0 || amountOnDraw > 0, NoBetFound());
    }

    function getNumBettors(uint256 _betId) external view returns (uint256 _numBettors) {
        require(_betId > 0, FieldsRequired());
        Bet storage m = userBets[_betId];
        require(m.exists, BetDoesNOTExist());
        _numBettors = m.numBettors;
    }
    function resultRequested(uint256 _betId) external view  returns (bool requested) {
        require(_betId > 0, FieldsRequired());
        Bet storage m = userBets[_betId];
        require(m.exists, BetDoesNOTExist());
        return m.resultRequested;
    }
    function isMatchCanceled(uint256 _betId) external view returns (bool canceled) {
        require(_betId > 0, FieldsRequired());
        Bet storage m = userBets[_betId];
        require(m.exists, BetDoesNOTExist());
        return m.canceled;
    }

    receive() external payable {}
}

