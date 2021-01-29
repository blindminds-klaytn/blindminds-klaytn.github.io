// @title BlindMinds.io Poll Betting Game
// @author Atomrigs Lab
// @version 1.1
// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.8.0;
pragma abicoder v2;

library SafeMath {
    
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");
        return c;
    }
    
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;
        return c;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold
        return c;
    }

    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }

    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}

interface IERC20 {
    
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract BlindPollBet {
    using SafeMath for uint256;
    using SafeMath for uint32;
    
    struct Bet {
        bool isPaid;
        uint8 choiceDecoded;
        address bettor;        
        uint32 betAmount;
        uint32 paidAmount;
        bytes32 choiceHash;
    }

    struct Poll {
        uint8 choiceCount;
        uint8 mode; // 0 -> low, 1 -> high, 2 -> highlow
        address creator;
        uint32 startTime;
        uint32 duration;
    }
    
    struct PollDetail {
        bool isPaid;
        bool isTerminated;
        uint32 betCount;    
        uint32 totalAmount;
        uint32 bonusAmount;
        uint32 operatorAmount;
        uint32 creatorAmount;
        bytes32 secretSalt;
    }
    
    struct GameInfo {
        uint32 totalPollCount;
        uint32 totalBetCount;
        uint32 totalBetAmount;
    }
    
    struct GameRule {
        uint8 operatorCommission; // 5% 
        uint8 creatorCommission; 
        uint8 maxChoiceCount;
        uint32 maxBetCount;
        uint32 minBetAmount;
        uint32 maxBetAmount; 
    }
    
    struct Calc {
        uint256 totalProfit;
        uint256 operatorAmount;
        uint256 creatorAmount;
        uint256 totalProfitShare;
        uint256 totalPaidAmount;
    }
    enum Status { pending, active, finished, paid, terminated }
    
    Poll[] public polls;
    PollDetail[] public pollDetails;
    GameInfo public gameInfo;
    GameRule public gameRule;

    //mapping(uint256 => string[]) public pollChoices;
    mapping(uint32 => Bet[]) public bets;
    mapping(uint32 => mapping(uint8 => uint32)) public pollResults; //pollId => choice => totalTokens
    mapping(uint32 => mapping(uint8 => uint8)) public winningChoices; //pollId => choice => winning Status
    // 0 => lost 1 => low win 2=> high win
    mapping(uint32 => uint32) public blockByCounter;    
    
    
    uint32 public deployedBlock;
    address operator;
    uint256 decimal = 10**18;
    bool newPollAllow = true;
    

    address public tokenAddress; // ERC20 contract

    event PollCreated(uint32 indexed pollId, address indexed creator, uint32 startTime, uint32 duration, uint8 mode, string question);
    event BetCreated(uint32 indexed pollId, address indexed bettor, uint256 index, uint256 amount, uint32 totalBetCount, uint32 totalBetAmount);
    event PollPaid(uint32 indexed pollId, address indexed bettor, uint256 amount, uint8 payType);
    //paytype 0 => refund, 1 => win_reward, 2 => creator_commision, 3=> operator_commision
    event PollRevealed(uint32 indexed pollId);
    
    modifier onlyOperator() {
        require(msg.sender == operator);
        _;
    }    
    
    constructor() {
        deployedBlock = uint32(block.number);
        operator = msg.sender;
        tokenAddress = 0xAF5E8215f2A9B91946B91C03d93b6683FD9baedd;
    
        gameRule = GameRule({
            operatorCommission: 5, // 5% 
            creatorCommission: 5,
            maxChoiceCount: 10,
            maxBetCount: 100,
            minBetAmount: 1, // unit is dkey
            maxBetAmount: 1000 // unit is dkey
        });
        
        gameInfo = GameInfo({
            totalPollCount: 0,
            totalBetCount: 0,
            totalBetAmount: 0
        });
    }

    function createPoll(uint32 _startTime,
                        uint32 _duration,
                        string memory _question,
                        string[] memory _choices,
                        string[] memory _choiceUrls,
                        uint8 _mode,
                        string memory _jsonData                        
                        ) public returns (uint256 pollId) {
        require(newPollAllow, "The game does not accept new polls at the moment.");
        uint8 choiceCount = uint8(_choices.length);
        require(_mode <= 2, "The game mode should be 0(low), 1(high), or 2(highlow).");
        require(choiceCount <= gameRule.maxChoiceCount, "The maximum number of choices is 10.");
        if (_mode == 2) {
            require(choiceCount > 2, "If the mode is highlow, the number of choices should be more than 2.");
        }

        if (_startTime == 0) { _startTime = uint32(block.timestamp); }
        
        Poll memory poll  = Poll({
            choiceCount: choiceCount,
            mode: _mode,
            creator: msg.sender,
            startTime: _startTime,
            duration: _duration
        });

        PollDetail memory pollDetail = PollDetail({
            isPaid: false,
            isTerminated: false,
            betCount: 0,
            totalAmount: 0,
            bonusAmount: 0,
            operatorAmount: 0,
            creatorAmount: 0,
            secretSalt: "0x0"
        });
        polls.push(poll);
        pollDetails.push(pollDetail);
        require(polls.length == pollDetails.length);
        pollId = polls.length - 1;

        gameInfo.totalPollCount ++;
        blockByCounter[gameInfo.totalPollCount] = uint32(block.number);
        emit PollCreated(uint32(pollId), msg.sender, _startTime, _duration, _mode, _question);
        return pollId;
    }
    
    function getBets(uint32 _pollId) external view returns (Bet[] memory) {
        return bets[_pollId];
    }

    function getStatus(uint32 _pollId) public view returns (Status) {
        Poll memory poll = polls[_pollId];
        PollDetail memory pollDetail = pollDetails[_pollId];
        if (pollDetail.isPaid) {
            if (pollDetail.isTerminated) {
                return Status.terminated;   
            } else {
                return Status.paid;
            }
        }
        if (uint32(block.timestamp) < poll.startTime) {
            return Status.pending;
        } else if (uint32(block.timestamp) < poll.startTime.add(poll.duration)) {
            return Status.active;
        } else {
            return Status.finished;
        }
    }
    
    function isFinished(uint32 _pollId) public view returns (bool) { 
        return getStatus(_pollId) >= Status.finished; 
    }    
    
    function isActive(uint32 _pollId) public view returns (bool) { 
        return getStatus(_pollId) == Status.active; 
    }
    
    function isPaid(uint32 _pollId) public view returns (bool) { 
        return getStatus(_pollId) >= Status.paid; 
    }
    
    function getPollCount() public view returns (uint32) {
        return uint32(polls.length);
    }
    

    function pollBet(uint32 _pollId, bytes32 _choiceHash, uint32 _betAmount ) public {
        Poll memory poll = polls[_pollId];
        PollDetail storage pollDetail = pollDetails[_pollId];
        require(poll.creator != address(0));
        require(_betAmount > 0);
        require(isActive(_pollId));
        require(bets[_pollId].length < gameRule.maxBetCount, "This poll can not receive more bets than the maximum limit.");
        require(_betAmount >= gameRule.minBetAmount, "The bet amount is lower than the minimum amount.");
        require(_betAmount <= gameRule.maxBetAmount, "The bet amount exceeded the allowed limit.");

        Bet memory bet = Bet({
            isPaid: false,
            choiceDecoded: 0,
            bettor: msg.sender,
            betAmount: _betAmount,            
            paidAmount: 0,
            choiceHash: _choiceHash
        });
        
        IERC20 token = IERC20(tokenAddress);
        require(token.transferFrom(msg.sender, address(this), decimal.mul(_betAmount)));        
        bets[_pollId].push(bet);
        pollDetail.betCount ++;
        pollDetail.totalAmount = uint32(pollDetail.totalAmount.add(_betAmount));
        if (_choiceHash == 0x0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef) {
            pollDetail.bonusAmount = uint32(pollDetail.bonusAmount.add(_betAmount));
        }
        gameInfo.totalBetCount ++;
        gameInfo.totalBetAmount = uint32(gameInfo.totalBetAmount.add(_betAmount));
        emit BetCreated(_pollId, msg.sender, bets[_pollId].length-1, _betAmount, gameInfo.totalBetCount, gameInfo.totalBetAmount);
    }
    
    
    function getHash(uint8 _choice, address _addr, bytes32 _secreteSalt) 
        public pure returns (bytes32) {
        return keccak256(abi.encodePacked(_choice, _addr, _secreteSalt));
    }
    
    function _revealChoices(uint32 _pollId, uint8 _choiceCount, bytes32 _secreteSalt) private returns (bool) {
        Bet[] storage targetBets = bets[_pollId];

        for (uint i = 0; i < targetBets.length; i++) { 
            Bet storage bet = targetBets[i];
            for(uint8 j = 1; j < _choiceCount + 1; j++) {
                if (getHash(j, bet.bettor, _secreteSalt) == bet.choiceHash) {
                    bet.choiceDecoded = j;
                    break;
                }
            }
            pollResults[_pollId][bet.choiceDecoded] += uint32(bet.betAmount);
        }
        return true;
    }
    
    function _decideWinningChoice(uint32 _pollId, uint8 _mode, uint8 _choiceCount) private returns (bool) {
        
        if (_mode == 0) { //low game
            uint lowest = 0;
            for (uint8 i = 1; i < _choiceCount + 1; i++) {
                uint amount = pollResults[_pollId][i];
                if (amount > 0) {
                    if(lowest == 0) {
                        lowest = amount;
                    } else if(amount < lowest) {
                        lowest = amount;
                    }
                } 
            }
            
            for (uint8 j = 1; j < _choiceCount + 1; j++) {
                if (pollResults[_pollId][j] == lowest) { 
                    winningChoices[_pollId][j] = 1; 
                }
            }
        } else if (_mode == 1) { //high game
            uint highest = 0;
            for (uint8 i = 1; i < _choiceCount + 1; i++) {
                uint amount = pollResults[_pollId][i];
                if (amount > highest) { 
                    highest = amount; 
                } 
            }
            
            for (uint8 j = 1; j < _choiceCount + 1; j++) {
                if (pollResults[_pollId][j] == highest) { 
                    winningChoices[_pollId][j] = 2; 
                }
            }
        } else { // highlow game
            uint lowest = 0;
            uint highest = 0;
            for (uint8 i = 1; i < _choiceCount + 1; i++) {
                uint amount = pollResults[_pollId][i];
                if (amount > 0) {
                    if(lowest == 0) {
                        lowest = amount;
                    } else if(amount < lowest) {
                        lowest = amount;
                    }
                } 
                if (amount > highest) { 
                    highest = amount; 
                } 
            }
            
            for (uint8 j = 1; j < _choiceCount + 1; j++) {
                uint amount = pollResults[_pollId][j];
                if (amount == highest) {
                    winningChoices[_pollId][j] = 2; 
                }
                else if(amount == lowest) { 
                    winningChoices[_pollId][j] = 1; 
                }
            }
        }
        return true;
    }
    
    function _calcTotalWinChoiceAmount(uint32 _pollId, uint8 _choiceCount) private view returns (uint256, uint256) {
        
        uint256 totalWinChoiceAmount = 0;
        uint256 lowWinAmount = 0;

        for (uint8 i = 1; i < _choiceCount + 1; i++) {
            if (winningChoices[_pollId][i] > 0) {
                totalWinChoiceAmount = totalWinChoiceAmount.add(pollResults[_pollId][i]);
            }
            if (winningChoices[_pollId][i] == 1) {
                lowWinAmount = lowWinAmount.add(pollResults[_pollId][i]);
            }
        }
        return (totalWinChoiceAmount, lowWinAmount);
    }

    function payPoll(uint32 _pollId, bytes32 _secreteSalt) public onlyOperator() returns (bool) {
        Poll memory poll = polls[_pollId];
        PollDetail storage pollDetail = pollDetails[_pollId];
        require(isFinished(_pollId), "The poll is not finished yet.");
        pollDetail.secretSalt = _secreteSalt;
        if (pollDetail.betCount == 0) {
            pollDetail.isPaid = true;
            return true;
        }
        require(_revealChoices(_pollId, poll.choiceCount, _secreteSalt), "Revealing choices failed.");
        require(_decideWinningChoice(_pollId, poll.mode, poll.choiceCount), "Deciding winning choices failed.");
        (uint256 totalWinChoiceAmount, uint256 lowWinAmount) = _calcTotalWinChoiceAmount(_pollId, poll.choiceCount);

        if (totalWinChoiceAmount == 0) { //refund
            require(terminatePoll(_pollId));
            return true;
        }
        
        Calc memory c = Calc({
            totalProfit: 0,
            operatorAmount: 0,
            creatorAmount: 0,
            totalProfitShare: 0,
            totalPaidAmount: 0
        });
        c.totalProfit = pollDetail.totalAmount.sub(totalWinChoiceAmount);
        c.operatorAmount = (c.totalProfit.mul(gameRule.operatorCommission)).div(100);
        c.creatorAmount = (c.totalProfit.mul(gameRule.creatorCommission)).div(100);
        c.totalProfitShare = c.totalProfit.sub(c.operatorAmount.add(c.creatorAmount));
        c.totalPaidAmount = 0;

        IERC20 token = IERC20(tokenAddress);
        Bet[] storage targetBets = bets[_pollId];
        
        for (uint i = 0; i < targetBets.length; i++) { 
            Bet storage bet = targetBets[i];
            uint8 winType = winningChoices[_pollId][bet.choiceDecoded];
            uint256 paidAmount;
            if (winType > 0) {
                if (lowWinAmount == 0 || totalWinChoiceAmount == lowWinAmount) { // high or low win
                    paidAmount = bet.betAmount.add((c.totalProfitShare.mul(bet.betAmount)).div(totalWinChoiceAmount));
                } else {
                    if (winType == 1) {
                        paidAmount = bet.betAmount.add(((c.totalProfitShare.div(2)).mul(bet.betAmount)).div(lowWinAmount));
                    } else {
                        paidAmount = bet.betAmount.add(((c.totalProfitShare.div(2)).mul(bet.betAmount)).div(totalWinChoiceAmount.sub(lowWinAmount)));
                    }
                }
                require(token.transfer(bet.bettor, decimal.mul(paidAmount)));
                bet.paidAmount = uint32(paidAmount);
                c.totalPaidAmount = c.totalPaidAmount.add(paidAmount);
                emit PollPaid(_pollId, bet.bettor, paidAmount, 1);
            }
            bet.isPaid = true;
        }

        if (c.creatorAmount > 0) {
            require(token.transfer(poll.creator, decimal.mul(c.creatorAmount)));    
            emit PollPaid(_pollId, poll.creator, c.creatorAmount, 2);
            c.totalPaidAmount = c.totalPaidAmount.add(c.creatorAmount);
        }
        c.operatorAmount = pollDetail.totalAmount.sub(c.totalPaidAmount);
        if (c.operatorAmount > 0) {
            require(token.transfer(operator, decimal.mul(c.operatorAmount)));
            emit PollPaid(_pollId, operator, c.operatorAmount, 3);
                
        }
        pollDetail.isPaid = true;
        pollDetail.operatorAmount = uint32(c.operatorAmount);
        pollDetail.creatorAmount = uint32(c.creatorAmount);
        emit PollRevealed(_pollId);
        return true;
    }

    function getPollResult(uint32 _pollId) external view returns (uint32[] memory) {
        Poll memory poll = polls[_pollId];
        uint32[] memory resultList = new uint32[](poll.choiceCount+1);
        for (uint8 i = 0; i < poll.choiceCount+1; i++) { 
            if (pollResults[_pollId][i] > 0) {
                resultList[i] = pollResults[_pollId][i];
            } else {
                resultList[i] = 0;
            }
        }
        return resultList;
    }
    
    function getWiningChoices(uint32 _pollId) external view returns (uint8[] memory) {
        Poll memory poll = polls[_pollId];
        uint8[] memory resultList = new uint8[](poll.choiceCount+1);
        for (uint8 i = 0; i < poll.choiceCount+1; i++) { 
            if (winningChoices[_pollId][i] > 0) {
                resultList[i] = winningChoices[_pollId][i];
            } else {
                resultList[i] = 0;
            }
        }
        return resultList;
    }    

    function terminatePoll(uint32 _pollId) public onlyOperator() returns(bool) {
        PollDetail storage pollDetail = pollDetails[_pollId];
        require(!pollDetail.isPaid);
        
        IERC20 token = IERC20(tokenAddress);
        Bet[] storage targetBets = bets[_pollId];
        
        for (uint i = 0; i < targetBets.length; i++) { 
            Bet storage bet = targetBets[i];
            require(token.transfer(bet.bettor, decimal.mul(bet.betAmount)));
            bet.paidAmount = bet.betAmount;
            bet.isPaid = true;
            emit PollPaid(_pollId, bet.bettor, bet.betAmount, 0);
        }
        pollDetail.isPaid = true;
        pollDetail.isTerminated = true;
        return true;
    }

    function updateToken(address _tokenAddr) public onlyOperator() returns (bool) {
        for(uint32 i = 0; i < polls.length; i++) {
            require(isPaid(i));
        }
        tokenAddress = _tokenAddr;
        return true;
    }    
    
    function setNewPollAllow(bool _val) public onlyOperator() returns (bool) {
        newPollAllow = _val;
        return true;
    }

    function withdrawTo(address _toAddr, uint256 _amount) public onlyOperator() returns (bool) {
        for(uint32 i = 0; i < polls.length; i++) {
            require(isPaid(i));
        }
        IERC20 token = IERC20(tokenAddress);        
        require(token.transfer(_toAddr, decimal.mul(_amount)));
        return true;
    }
    
    function setMinBetAmount(uint32 _val) public onlyOperator() returns (bool) {
        gameRule.minBetAmount = _val;
        return true;
    }
    
    function setMaxBetAmount(uint32 _val) public onlyOperator() returns (bool) {
        gameRule.maxBetAmount = _val;
        return true;
    }
    
    function setMaxBetCount(uint16 _val) public onlyOperator() returns (bool) {
        gameRule.maxBetCount = _val;
        return true;
    }
}
