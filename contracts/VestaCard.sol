// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;
import "contracts/ERC20Callback.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";
import {ECDSA} from  "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@chainlink/contracts/src/v0.8/ConfirmedOwner.sol";
import '@chainlink/contracts/src/v0.8/VRFV2WrapperConsumerBase.sol';


interface IVestaRandomizer{
    function requestRandomWords() external returns(uint256);
    function isFullfilled(uint256 requestId) view external returns(bool);
    function getNumber(uint256 requestId) view external returns(uint256);
    
}

interface IVestaToken{
    function mint(address to, uint256 amount) external;
}

contract VestaCard is Initializable, OwnableUpgradeable {
/// @custom:oz-upgrades-unsafe-allow constructor
    using SafeERC20Upgradeable for IERC20Upgradeable;
    //external smart contracts
    IVestaRandomizer randomizer;
    IERC20Upgradeable vestaToken;
    address vestaTokenAddress;

    //objects
    struct Card {
          uint256 card_id;
          uint8 color;
          uint8 evolution;
          uint8 tier;
          uint8 symbol;
          uint256 cardPower;
          uint256 initialPower;
          uint256 created; //timestamp 
          bool banished;
    }
    struct Vesting{
        uint256 id;
        uint256 start;
        uint256 amount;
        uint256 released;
    }
    uint256 nonce;
    mapping (uint256=>address) cardOwner;
    mapping (address=>uint256[]) cardsByOwner;
    mapping (uint256=>address) vestOwner;
    mapping (address=>uint256[]) vestsByOwner;
    mapping (address=>uint256) unlockedClaimableToken;
    mapping (address=>uint256) staked;
    mapping(address => bool) private _isValidSigner;
    mapping(address => bool) _signedUnlock;
    mapping(uint256=>uint256) salePrice;
    address[] private signerAdmin;
    

    uint private _threshold;
    uint private signCount;
    bool panicUnlock;
    uint8[] symbols;
    Vesting[] vestingIndex;
    Card[] cardIndex;
    bool[] saleIndex;

    mapping (address=>bool) blacklisted;


    //Chainlink Mock for testing purpose
    uint256 generatedNumber;
    bool test;

    //no constructor for Upgradeable contract
    function initialize(address _randomizer, address _vestaTokenAddress, address[] memory _signers, bool _test)   initializer  public {
        __Ownable_init();
        //initiate linked smart contracts
        vestaToken = IERC20Upgradeable(_vestaTokenAddress);
        vestaTokenAddress = _vestaTokenAddress;
        randomizer = IVestaRandomizer(_randomizer);
        //multi sigs
        _threshold = _signers.length;
        for (uint i=0; i < _threshold; i++) {
            _isValidSigner[_signers[i]] = true;
            signerAdmin.push(_signers[i]);
        } 
        //assign initial values
        panicUnlock=false;
        symbols=[7,4,2,0];
        generatedNumber=78412856354;
        test=_test;
    }

    // set functions
    function setRandomizer(address _addr) public onlyOwner {
        randomizer=IVestaRandomizer(_addr);
    }
    function setToken(address _addr) public onlyOwner {
        vestaToken=IERC20Upgradeable(_addr);
        vestaTokenAddress=_addr;
    }

    function mintVestaToken(uint256 amount) public onlyOwner {
        IVestaToken(vestaTokenAddress).mint(msg.sender,amount);
    }
    //checking if wallet has sufficient fund, allowance, and not blacklisted
    function checkWallet(address _addr, uint256 _amount) public view returns(bool){
        if(vestaToken.balanceOf(_addr)>=_amount&&vestaToken.allowance(_addr, address(this))>=_amount&&!blacklisted[_addr]){
            return true;
        }else
        return false;
    }

    //basic stake and unstake function
    function stake(uint256 _amount) public{
        bool walletChecked = checkWallet(msg.sender, _amount);
        require(walletChecked,"insufficient balance, insufficient allowance, or blacklisted");
        vestaToken.safeTransferFrom(msg.sender,address(this), _amount);
        
        staked[msg.sender]+=_amount;
    }
    function unstake(uint256 _amount, address _address) public {
        require(_amount<=staked[_address],"staked amount insufficient");
        vestaToken.safeTransfer(_address, _amount);
        staked[_address]-=_amount;
    }
    function getStakedAmount()public view returns(uint256){
        return(staked[msg.sender]);
    }
    function getStakedAmountOf(address _addr)public view onlyOwner returns(uint256){
        return(staked[_addr]);
    }
    //lock / vesting token, each user can vest more than once (multiple vestings)
    function vestToken(uint256 _amount) public {
        require(!blacklisted[msg.sender],"blacklisted");
        bool walletChecked = checkWallet(msg.sender, _amount);
        require(walletChecked,"insufficient balance, insufficient allowance, or blacklisted");
        vestaToken.safeTransferFrom(msg.sender,address(this), _amount ) ;
        //put vesting to an object and index it
        Vesting memory _vest;
        _vest.id= vestingIndex.length;
        _vest.start=block.timestamp;
        _vest.amount=_amount;
        vestsByOwner[msg.sender].push(_vest.id);
        vestingIndex.push(_vest);
        vestOwner[_vest.id]=msg.sender;
    }

    //vested / locked for a year with gradually released per month
    function getUnlockableToken(uint256 _vestIndex) public view returns(uint256){
        uint256 _vested = ((block.timestamp-vestingIndex[_vestIndex].start)/30 days);
        if(_vested>12)_vested=12;
        //below is to calculate the vesting period and unlockable tokens
        uint256 unlockableToken = ((_vested)/30 days)/12*vestingIndex[_vestIndex].amount-vestingIndex[_vestIndex].released;
        return unlockableToken;
    }
    //user can claim released token OR if there is a panic unlock triggered
    function releaseVest(uint256 _vestIndex) public{
        require(vestOwner[_vestIndex]==msg.sender,"not the owner");
        if(!panicUnlock){
            uint256 unlockableToken = getUnlockableToken(_vestIndex);
            vestaToken.safeTransferFrom(address(this), msg.sender, unlockableToken);
            vestingIndex[_vestIndex].released=unlockableToken;
        }else{
            vestaToken.safeTransferFrom(address(this), msg.sender, (vestingIndex[_vestIndex].amount-vestingIndex[_vestIndex].released));
        }

    }

    function getVestings() public view returns(Vesting [] memory)
    {
        Vesting [] memory returnVest = new Vesting [] (vestsByOwner[msg.sender].length);
        for(uint256 i=0;i<vestsByOwner[msg.sender].length;i++){
            returnVest[i]=vestingIndex[vestsByOwner[msg.sender][i]];
        }
        return returnVest;

    }

    //panic release for locked / vested token, multisigs by a group of admin
    function unlockAll () public
    {
        require(_isValidSigner[msg.sender],"not part of consortium");
        require(!_signedUnlock[msg.sender],"already signed for panic unlock");
        _signedUnlock[msg.sender]=true;
        signCount++;

        if(signCount==_threshold){
            panicUnlock=true;
        }
    }

    function isUnlocked() public view returns(bool){
        return panicUnlock;
    }

    function requestRandomNumber() public onlyOwner returns(uint256){
        return randomizer.requestRandomWords();
        //return randomizer.getRandomNumber(_random);
    }
    function getRandomNumber(uint256 requestId) public view onlyOwner returns(uint256){
        return randomizer.getNumber(requestId);
    }
        
    //create card with unique random values taken from chainlink API
    //it took 1 random number to be used as the base of card properties
    //if MOCK = true, it will take the value from "generatedNumber" variable instead of requesting to Chainlink
    function createCard(uint256 _amount, bool _mock) public returns(uint256){
        bool walletChecked = checkWallet(msg.sender, _amount);
        require(walletChecked,"insufficient balance, insufficient allowance, or blacklisted");
        vestaToken.safeTransferFrom(msg.sender,address(this), _amount);
        Card memory _card;
        bool fullfilled=false;
        uint256 _result=0;
        bool mock=false;
        if(test)mock=_mock;else mock=false;
        if(!mock){
            uint256 _requestId = randomizer.requestRandomWords();
            uint256 lastCheck = block.timestamp;
            while(block.timestamp<=lastCheck + 20 seconds){ //wait until the random number generated, OR until 20 seconds max
                if(randomizer.isFullfilled(_requestId)){
                    _result=randomizer.getNumber(_requestId);
                    fullfilled=true;
                    break;
                }
            }
        }else{
             fullfilled=true;
             _result=generatedNumber;
             generatedNumber++;
        }
        require(fullfilled,"failed generating card value");
        //proceed to use the number as the base of card properties value
        _card.color=(uint8)(_result % 3)+1;
        _card.tier=(uint8)(_result % 5)+1;
        _card.symbol=symbols[(uint8)(_result % 3)+1];
        _card.evolution=(uint8)(_result % 100)+1;
        _card.card_id=cardIndex.length;
        _card.initialPower=_amount/100; //1 token = 0.01 power
        _card.created=block.timestamp;
        _card.banished=false;
        cardsByOwner[msg.sender].push(_card.card_id);
        cardIndex.push(_card);
        
        saleIndex.push(false);
        cardOwner[_card.card_id]=msg.sender;
        return _card.card_id;
    }


    //each day, cards will get more power based on calculation in this function
    function getCardPower(uint256 _cardId)public view returns (uint256){
        //cardPower += evolution * (InitialCardPower * (tier number + color + symbol)) 
        require(!cardIndex[_cardId].banished,"card is banished");
        return ((block.timestamp-cardIndex[_cardId].created)/ 1 days)*((cardIndex[_cardId].evolution/100) * (cardIndex[_cardId].initialPower*(cardIndex[_cardId].tier + cardIndex[_cardId].color + cardIndex[_cardId].symbol)));
    }

    function getCardDetail(uint256 _cardId)public view returns(uint256 [] memory){
        uint256 [] memory cardDetail = new uint256[](7);
        cardDetail[0]=cardIndex[_cardId].color;
        cardDetail[1]=cardIndex[_cardId].evolution;
        cardDetail[2]=cardIndex[_cardId].tier;
        cardDetail[3]=cardIndex[_cardId].symbol;
        cardDetail[4]=cardIndex[_cardId].initialPower;
        cardDetail[5]=cardIndex[_cardId].created;
        cardDetail[6]=cardIndex[_cardId].card_id;
        return cardDetail;
      
    }

    function getCardsOwned(address _addr)public view returns(uint256){
        return cardsByOwner[_addr].length;
    }

    function getCardsOwnedAsObject(address _addr)public view returns(Card[] memory){
        Card [] memory _cards = new Card[] (cardsByOwner[_addr].length);
        for(uint256 i=0;i<_cards.length;i++){
            _cards[i]=cardIndex[cardsByOwner[_addr][i]];
        }
        return _cards;
    }


    //mark card as for sale
    function sellCard(uint256 _card, uint256 _amount) public{
        require(!cardIndex[_card].banished,"card is banished");
        require(msg.sender==cardOwner[_card], "must be owner to sell");
        saleIndex[_card]=true;
        salePrice[_card]=_amount;
    }
    function isOnSale(uint256 _card) public view returns(bool){
        require(!cardIndex[_card].banished,"card is banished");
        
        return saleIndex[_card];
    }
    //unsell
    function unSellCard(uint256 _card) public{
        require(!cardIndex[_card].banished,"card is banished");
        require(saleIndex[_card], "card is not for sell");
        require(msg.sender==cardOwner[_card], "must be owner to unsell");
        saleIndex[_card]=false;
    }
    //buy card
    function buyCard(uint256 _card, uint256 _amount) public{
        require(!cardIndex[_card].banished,"card is banished");
        bool walletChecked = checkWallet(msg.sender, _amount);
        require(walletChecked,"insufficient balance, insufficient allowance, or blacklisted");
        vestaToken.safeTransferFrom(msg.sender,cardOwner[_card], _amount);
        cardOwner[_card]=msg.sender;
        saleIndex[_card]=false;
    }

    function banishCard(uint256 _card) public{
        require(!cardIndex[_card].banished,"card is banished");
        uint256 amount = getCardPower(_card);
        vestaToken.safeTransferFrom(address(this),cardOwner[_card], amount);
        cardIndex[_card].banished=true;
    }

    function blacklist(address _addr) public onlyOwner{
        blacklisted[_addr]=true;
    }

    function unblacklist(address _addr) public onlyOwner{
        blacklisted[_addr]=false;
    }

    function isBlacklisted(address _addr) public view returns(bool){
        return blacklisted[_addr];
    }


}