pragma solidity ^0.4.23;

import "./Ownable.sol";
import "./SafeMath.sol";
import "./SCUToken.sol";
import "./Fiat.sol";
import "./FiatMock.sol"; // only for Rinkeby and in-memory testing
//https://fiatcontract.com/#implement

contract SCUTokenCrowdsale is Ownable {
    using SafeMath for uint64;
    using SafeMath for uint256;

    //Whitepaper Page 49

    // Address of the beneficiary which will receive the raised ETH
    // Initialized during deployment
    address public beneficiary;

    // Deadline of the ICO as epoch time
    // Initialized when entering the first phase
    uint256 public deadline;

    // Amount raised by the ICO in Euro
    // Initialized during deployment
    uint256 public amountRaisedEUR;

    // Amount raised by the ICO in Ether
    // Initialized during deployment
    uint256 public amountRaisedETH;

    // Amount of tokens sold in Sip
    // Initialized during deployment
    uint256 public tokenSold;

    // Indicator if the funding goal has been reached
    // Initialized during deployment
    bool public fundingGoalReached;

    // Internal indicator if we have checked our goals at the end of the ICO
    // Initialized during deployment
    bool private goalChecked;

    // Indicator if the ICO already closed
    // Initialized during deployment
    bool public crowdsaleClosed;

    // Instance of our deployed SCU Token
    // Initialized during deployment
    SCUToken public tokenReward;

    // Instance of the FIAT contract we use for ETH/EUR conversion
    // Initialized during deployment
    FiatContract public fiat;

    // Amount of Euro cents we need to reach for the softcap
    uint256 private minTokenSellInEuroCents = 460000000;

    // Maximum amount of Euro cents a non-verified customer can invest
    //@QUESTION - Could deleted?
    uint256 private maxNonVerifiedCustomerEuroCents = 500000;

    // Minimum amount of tokens (in Sip) which are sold at the softcap
    // 4.600.000 is 29,48 % of 15.600.000
    // 78.000.000 * 29,48 = 22994400
    // ratio calc
    uint256 private minTokenSell = 2583333 * 1 ether;

    // Maximum amount of tokens (in Sip) which are sold at the hardcap
    // 78000000
    uint256 private maxTokenSell = 78000000 * 1 ether;

    // Minimum amount of tokens (in Sip) which the beneficiary will receive
    // for the founders at the softcap
    uint256 private minFounderToken = 2583333 * 1 ether;

    // Maximum amount of tokens (in Sip) which the beneficiary will receive
    // for the founders at the hardcap
    // 2583333 tokens
    // take all
    uint256 private maxFounderToken = 2583333 * 1 ether;

// Bountry Programm not edited
// QUESTION: need information for filling out variables
// --------------------------------------------------------------------------

    // Minimum amount of tokens (in Sip) which the beneficiary will receive
    uint256 private minRDAToken = 0 * 1 ether;

    // Maximum amount of tokens (in Sip) which the beneficiary will receive
    uint256 private maxRDAToken = 0 * 1 ether;

    // Amount of tokens (in Sip) which a customer will receive as bounty
    uint256 private bountyTokenPerPerson = 5 * 1 ether;

    // Maximum amount of tokens (in Sip) which are available for bounty
    uint256 private maxBountyToken = 0 * 1 ether;

    // Amount of tokens which are left for bounty
    // Initialized during deployment
    uint256 public tokenLeftForBounty;

// --------------------------------------------------------------------------

    // The pre-sale phase of the ICO
    // tokenPrice in cents
    // QUESTION: need information for filling out variables
    Phase private preSalePhase = Phase({
        id: PhaseID.PreSale,
        tokenPrice: 20,
        tokenForSale: 333333 * 1 ether,
        tokenLeft: 333333 * 1 ether
    });

    // The first public sale phase of the ICO
    Phase private firstPhase = Phase({
        id: PhaseID.First,
        tokenPrice: 20,
        tokenForSale: 2250000 * 1 ether,
        tokenLeft: 2250000 * 1 ether
    });

    // The second public sale phase of the ICO
    Phase private secondPhase = Phase({
        id: PhaseID.Second,
        tokenPrice: 20,
        tokenForSale: 21000000 * 1 ether,
        tokenLeft: 21000000 * 1 ether
    });

    // The third public sale phase of the ICO
    Phase private thirdPhase = Phase({
        id: PhaseID.Third,
        tokenPrice: 20,
        tokenForSale: 1666667 * 1 ether,
        tokenLeft: 1666667 * 1 ether
    });

    // The closed phase of the ICO
    // No token for sell
    Phase private closedPhase = Phase({
        id: PhaseID.Closed,
        tokenPrice: ~uint64(0),
        tokenForSale: 0,
        tokenLeft: 0
    });

    // Points to the current phase
    Phase public currentPhase;

    // Structure for the phases
    // Consists of an id, the tokenPrice and the amount
    // of tokens available and left for sale
    struct Phase {
        PhaseID id;
        uint64 tokenPrice;
        uint256 tokenForSale;
        uint256 tokenLeft;
    }

    // Enumeration for identification of the phases
    enum PhaseID {
        PreSale,        // 0
        First,          // 1
        Second,         // 2
        Third,          // 3
        Closed          // 4
    }

    // Mapping of an address to a customer
    mapping(address => Customer) public customer;

    // Structure representing a customer
    // Consists of a rating, the amount of Ether and Euro the customer raised,
    // and a boolean indicating if he/she has already received a bounty
    struct Customer {
        Rating rating;
        uint256 amountRaisedEther;
        uint256 amountRaisedEuro;
        uint256 amountReceivedSCUToken;
        bool hasReceivedBounty;
    }

    // Enumeration for identification of a rating for a customer
    // @// QUESTION: Could deleted ?
    enum Rating {
        Unlisted,       // 0: No known customer, can't buy any token
        Whitelisted,    // 1: Known customer by personal data, allowed to buy token up to 5.000 EUR
        Verified        // 2: Known and verified customer by passport, allowed to buy any number of token
    }

    // Event definitions
    event SaleClosed();
    event GoalReached(address recipient, uint256 tokensSold, uint256 totalAmountRaised);
    event CustomerRating(address indexed customer, Rating rating);
    event PhaseEntered(PhaseID phaseID);
    event TokenSold(address indexed customer, uint256 amount);
    event BountyTransfer(address indexed customer, uint256 amount);
    event FounderTokenTransfer(address recipient, uint256 amount);
    event RDATokenTransfer(address recipient, uint256 amount);
    event FundsWithdrawal(address indexed recipient, uint256 amount);

    // Constructor which gets called once on contract deployment
    constructor() public {
        beneficiary = msg.sender;
        tokenReward = new SCUToken(msg.sender);
        fiat = new FiatContractMock();  // Rinkeby and in-memory
        currentPhase = preSalePhase;
        fundingGoalReached = false;
        crowdsaleClosed = false;
        goalChecked = false;
        tokenLeftForBounty = maxBountyToken;
        tokenReward.transfer(msg.sender, currentPhase.tokenForSale);
        currentPhase.tokenLeft = 0;
        tokenSold += currentPhase.tokenForSale;
        amountRaisedEUR = amountRaisedEUR.add((currentPhase.tokenForSale.div(1 ether)).mul(currentPhase.tokenPrice));
    }

    /**
     * @notice Not for public use!
     * @dev Advances the crowdsale to the next phase.
     */
    function nextPhase() public onlyOwner {
        require(currentPhase.id != PhaseID.Closed);

        uint8 nextPhaseNum = uint8(currentPhase.id) + 1;

        if (PhaseID(nextPhaseNum) == PhaseID.First) {
            currentPhase = firstPhase;
            deadline = now + 110 * 1 days;
        }
        if (PhaseID(nextPhaseNum) == PhaseID.Second) {
            currentPhase = secondPhase;
        }
        if (PhaseID(nextPhaseNum) == PhaseID.Third) {
            currentPhase = thirdPhase;
        }
        if (PhaseID(nextPhaseNum) == PhaseID.Closed) {
            currentPhase = closedPhase;
        }

        emit PhaseEntered(currentPhase.id);
    }

    /**
     * @notice Not for public use!
     * @dev Set the rating of a customer by address.
     * @param _customer The address of the customer you want to change the rating of.
     * @param _rating The rating as an uint:
     * 0 => Unlisted
     * 1 => Whitelisted
     * 2 => Verified
     */
    function setCustomerRating(address _customer, Rating _rating) public onlyOwner {
        require(_customer != address(0));
        require(_rating == Rating.Unlisted || _rating == Rating.Whitelisted || _rating == Rating.Verified);

        customer[_customer].rating = _rating;
        emit CustomerRating(_customer, _rating);

        if (_rating > Rating.Unlisted && !customer[_customer].hasReceivedBounty && tokenLeftForBounty > 0) {
            customer[_customer].hasReceivedBounty = true;
            customer[_customer].amountReceivedSCUToken = customer[_customer].amountReceivedSCUToken.add(bountyTokenPerPerson);
            tokenLeftForBounty = tokenLeftForBounty.sub(bountyTokenPerPerson);
            tokenReward.transfer(_customer, bountyTokenPerPerson);
            emit BountyTransfer(_customer, bountyTokenPerPerson);
        }
    }


    modifier afterDeadline() {
        if ((now >= deadline && currentPhase.id >= PhaseID.First) || currentPhase.id == PhaseID.Closed) {
            _;
        }
    }

    /**
     * @dev Internal function for checking if we reached our funding goal.
     * @return Indicates if the funding goal has been reached.
     */
    function _checkFundingGoalReached() internal returns (bool) {
        if (!fundingGoalReached) {
            if (amountRaisedEUR >= minTokenSellInEuroCents) {
                fundingGoalReached = true;
            }
        }
        return fundingGoalReached;
    }

    /**
     * @dev Fallback function
     * The function without name is the default function that is called whenever anyone sends funds to a contract
     */
    function () external payable {
        _buyToken(msg.sender);
    }

    /**
     * @notice Buy tokens for ether. You can also just send ether to the contract to buy tokens.
     * Your address needs to be whitelisted first.
     * @dev Allows the caller to buy token for his address.
     * Implemented for the case that other contracts want to buy tokens.
     */
    function buyToken() external payable {
        _buyToken(msg.sender);
    }

    /**
     * @notice Buy tokens for another address. The address still needs to be whitelisted.
     * @dev Allows the caller to buy token for a different address.
     * @param _receiver Address of the person who should receive the tokens.
     */
    function buyTokenForAddress(address _receiver) external payable {
        require(_receiver != address(0));
        _buyToken(_receiver);
    }

    /**
     * @dev Internal function for buying token.
     * @param _receiver Address of the person who should receive the tokens.
     */
    function _buyToken(address _receiver) internal {
        require(!crowdsaleClosed);
        require(currentPhase.id != PhaseID.PreSale);
        require(currentPhase.id != PhaseID.Closed);
        require(customer[_receiver].rating >= Rating.Whitelisted);
        _sendTokenReward(_receiver);
        _checkFundingGoalReached();
    }

    /**
     * @dev Internal function for sending token as reward for ether.
     * @param _receiver Address of the person who should receive the tokens.
     */
    function _sendTokenReward(address _receiver) internal {
        // Remember the ETH amount of the message sender, not the token receiver!
        // We need this because if the softcap was not reached
        // the message sender should be able to retrive his ETH
        uint256 amount = msg.value;
        customer[msg.sender].amountRaisedEther = customer[msg.sender].amountRaisedEther.add(amount);
        amountRaisedETH = amountRaisedETH.add(amount);

        // Check if raised euro amount for customer would be more than his limit
        //@// QUESTION: Could deleted ?
        uint256 amountEuroCents = amount.div(fiat.EUR(0));
        uint256 sumAmountEuroCents = customer[_receiver].amountRaisedEuro.add(amountEuroCents);
        if (customer[_receiver].rating < Rating.Verified) {
            require(sumAmountEuroCents <= maxNonVerifiedCustomerEuroCents);
        }
        customer[_receiver].amountRaisedEuro = sumAmountEuroCents;
        amountRaisedEUR = amountRaisedEUR.add(amountEuroCents);

        uint256 tokenAmount = (amount / getTokenPrice()) * 1 ether;
        require(amountEuroCents >= 30);
        require(tokenAmount <= currentPhase.tokenLeft);
        currentPhase.tokenLeft = currentPhase.tokenLeft.sub(tokenAmount);

        customer[_receiver].amountReceivedSCUToken = customer[_receiver].amountReceivedSCUToken.add(tokenAmount);
        tokenSold = tokenSold.add(tokenAmount);
        tokenReward.transfer(_receiver, tokenAmount);
        emit TokenSold(_receiver, tokenAmount);
    }

    /**
     * @notice Withdraw your funds if the ICO softcap has not been reached.
     * @dev Checks to see if goal or time limit has been reached, and if so, and the funding goal was reached,
     * sends the entire ether amount to the beneficiary.
     * Also caluclates and sends the tokens for the founders, research & development and advisors.
     * All tokens which were not sold or send will be burned at the end.
     * If goal was not reached, each contributor can withdraw the amount they contributed.
     */
    function safeWithdrawal() public afterDeadline {
        require(crowdsaleClosed);

        if (!fundingGoalReached) {
            // Let customers retrieve their ether
            require(customer[msg.sender].amountRaisedEther > 0);
            uint256 amount = customer[msg.sender].amountRaisedEther;
            customer[msg.sender].amountRaisedEther = 0;
            msg.sender.transfer(amount);
            emit FundsWithdrawal(msg.sender, amount);
        } else {
            // Let owner retrive current ether amount and founder token
            require(beneficiary == msg.sender);
            uint256 ethAmount = address(this).balance;
            beneficiary.transfer(ethAmount);
            emit FundsWithdrawal(beneficiary, ethAmount);

            // Calculate and transfer founder token
            uint256 founderToken = (tokenSold - minTokenSell) * (maxFounderToken - minFounderToken) / (maxTokenSell - minTokenSell) + minFounderToken - (maxBountyToken - tokenLeftForBounty);
            require(tokenReward.transfer(beneficiary, founderToken));
            emit FounderTokenTransfer(beneficiary, founderToken);

            // Calculate and transfer research and advisor token
            uint256 rdaToken = (tokenSold - minTokenSell) * (maxRDAToken - minRDAToken) / (maxTokenSell - minTokenSell) + minRDAToken;
            require(tokenReward.transfer(beneficiary, rdaToken));
            emit RDATokenTransfer(beneficiary, rdaToken);

            // Burn all leftovers
            tokenReward.burn(tokenReward.balanceOf(this));
        }
    }

    /**
     * @notice Not for public use!
     * @dev Allows early withdrawal of ether from the contract if the funding goal is reached.
     * Only the owner and beneficiary of the contract can call this function.
     * @param _amount The amount of ETH (in wei) which should be retreived.
     */
    function earlySafeWithdrawal(uint256 _amount) public onlyOwner {
        require(fundingGoalReached);
        require(beneficiary == msg.sender);
        require(address(this).balance >= _amount);

        beneficiary.transfer(_amount);
        emit FundsWithdrawal(beneficiary, _amount);
    }

    /**
     * @dev Internal function to calculate token price based on the ether price and current phase.
     */
    function getTokenPrice() internal view returns (uint256) {
        return getEtherInEuroCents() * currentPhase.tokenPrice / 100;
    }

    /**
     * @dev Internal function to calculate 1 EUR in WEI.
     */
    function getEtherInEuroCents() internal view returns (uint256) {
        return fiat.EUR(0) * 100;
    }
}
