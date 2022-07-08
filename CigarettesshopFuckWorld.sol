// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "erc721a/contracts/extensions/ERC721AQueryable.sol";

contract ExclusiveCigarettesCrypto is ERC721AQueryable, Ownable, ReentrancyGuard {

    uint256 public constant TOTAL_SUPPLY = 10000;    

    uint256 public seasonSupply = 9000; 
    uint256 public Cost = 12 ether;  
    uint256 public WLCost = 6 ether;
    uint256 public maxCigarettesPerMint = 10;

    uint public charityProfit = 10;
    uint public artProfit = 35;
    uint public devProfit = 35;
    uint public marketingProfit = 10;
    uint public communityProfit = 10;

    bool public MintPaused = false;
    bool public Revealed = false;
    bool public isWhiteListActive = false;
    bool public isPublicSaleActive = false;

    mapping(address => uint8) public whiteList;

    address private charityWallet;
    address private artistWallet;
    address private devWallet;
    address private marketingWallet;
    address private communityWallet;
    
    string private baseTokenURI;

    constructor(
        string memory name_,
        string memory symbol_,    
        string memory initBaseURI_,
        address charityWallet_,
        address artistWallet_,
        address devWallet_,
        address marketingWallet_,
        address communityWallet_
    ) ERC721A ( name_, symbol_ ) {
        baseTokenURI = initBaseURI_;
        charityWallet = charityWallet_;
        artistWallet = artistWallet_;
        devWallet = devWallet_;
        marketingWallet = marketingWallet_;
        communityWallet = communityWallet_;
    }
    
    // Public functions
    function Mint(uint8 _mintAmount) external payable {
        uint256 nextTokenId = _nextTokenId();
        uint8 whiteListAmount = whiteList[msg.sender];

        require(!MintPaused, "The minting is paused by the moment");
        require(isWhiteListActive || isPublicSaleActive, "At least one type of sale must be active");

        require(_mintAmount > 0, "Provide mint amount major to 0");
        require(_mintAmount <= maxCigarettesPerMint, "Max Cigarettes per mint reached"); 
        require(nextTokenId + _mintAmount - 1 <= seasonSupply, "Max season supply reached");
        require(nextTokenId + _mintAmount - 1 <= TOTAL_SUPPLY, "Max supply reached"); 

        if(isWhiteListActive && (whiteListAmount > 0)){
            if(_mintAmount <= whiteListAmount){
                require(msg.value >= WLCost * _mintAmount, "Insufficient funds"); 

                whiteList[msg.sender] -= _mintAmount;
                _safeMint(msg.sender, _mintAmount);
            }else if(isPublicSaleActive){
                require(msg.value >= (WLCost * whiteListAmount) + (Cost * (_mintAmount - whiteListAmount)), "Insufficient funds"); 

                whiteList[msg.sender] -= whiteListAmount;
                _safeMint(msg.sender, _mintAmount);
            }else{
                require(_mintAmount <= whiteListAmount, "Exceeded max available to purchase");
            }
        }else if(isPublicSaleActive){
            require(msg.value >= Cost * _mintAmount, "Insufficient funds");   

            _safeMint(msg.sender, _mintAmount);
        }else{
            require(whiteListAmount > 0, "You must have at least one NFT left in Whitelist");
        }
    }

    function numAvailableToMint(address _addr) external view returns (uint8) {
        return whiteList[_addr];
    }

    function tokenURI(uint256 tokenId) public view virtual override(ERC721A, IERC721A) returns (string memory) {
        require( _exists(tokenId), "ERC721Metadata: URI query for nonexistent token" );   

        string memory currentBaseURI = _baseURI();

        if(Revealed == false) {      
            return bytes(currentBaseURI).length > 0 ? string(abi.encodePacked(currentBaseURI, "incognito.json")) : "";
        }else{       
            return bytes(currentBaseURI).length > 0 ? string(abi.encodePacked(currentBaseURI, _toString(tokenId), ".json")) : "";
        }
    }

    // Internal functions
    function _baseURI() internal view virtual override returns (string memory) {
        return baseTokenURI;
    }

    // Owner functions
    function changeStateMintPause() external onlyOwner {
        MintPaused = !MintPaused;
    }

    function changeStateReveal() external onlyOwner {
        Revealed = !Revealed;
    }

    function changeStateIsWhiteListActive() external onlyOwner {
        isWhiteListActive = !isWhiteListActive;
    }

    function changeStateIsPublicSaleActive() external onlyOwner {
        isPublicSaleActive = !isPublicSaleActive;
    }

    function setCost(uint256 _newCost) external onlyOwner {
        Cost = _newCost;
    }

    function setWLCost(uint256 _newWLCost) external onlyOwner {
        WLCost = _newWLCost;
    }

    function setSeasonSupply(uint256 _newSeasonSupply) external onlyOwner {
        seasonSupply = _newSeasonSupply;
    }

    function setCigarettesPerMint(uint256 _newMaxCigarettesPerMint) external onlyOwner {
        maxCigarettesPerMint = _newMaxCigarettesPerMint;
    }

    function setBaseURI(string calldata _newBaseURI) external onlyOwner {
        baseTokenURI = _newBaseURI;
    }

    function setWhiteList(address[] calldata addresses, uint8 numAllowedToMint) external onlyOwner {
        for (uint256 i = 0; i < addresses.length; i++) {
            whiteList[addresses[i]] = numAllowedToMint;
        }
    }

    function ownerMint(address _addr, uint256 _mintAmount) external onlyOwner {
        uint256 nextTokenId = _nextTokenId();

        require(nextTokenId + _mintAmount - 1 <= seasonSupply, "Max season supply reached");
        require(nextTokenId + _mintAmount - 1 <= TOTAL_SUPPLY, "Max supply reached"); 

        require(_mintAmount > 0, "Provide mint amount major to 0");

        _safeMint(_addr, _mintAmount);
    }   

    function changeMarketingWallet(address _newMarketingWallet) external onlyOwner{
        marketingWallet = _newMarketingWallet;
    }

    function profits(uint _charityProfit, uint _artProfit, uint _devProfit, uint _marketingProfit, uint _communityProfit) external onlyOwner{

        require(_charityProfit + _artProfit + _devProfit + _marketingProfit + _communityProfit == 100);

        charityProfit = _charityProfit;
        artProfit = _artProfit;
        devProfit = _devProfit;
        marketingProfit = _marketingProfit;
        communityProfit = _communityProfit;
    }

    function payProfits() external onlyOwner nonReentrant{

        uint charityPay = (address(this).balance * charityProfit / 100);
        uint artPay = (address(this).balance * artProfit / 100);
        uint devPay = (address(this).balance * devProfit / 100);
        uint marketingPay = (address(this).balance * marketingProfit / 100);
        uint communityPay = (address(this).balance * communityProfit / 100);

        require(charityPay + artPay + devPay + marketingPay + communityPay == address(this).balance);

        (bool charityPaySuccess, ) = charityWallet.call{value: charityPay}("");
        require(charityPaySuccess, "Transfer to charity failed.");
        
        (bool artistPaySuccess, ) = artistWallet.call{value: artPay}("");
        require(artistPaySuccess, "Transfer to artist failed.");

        (bool developerPaySuccess, ) = devWallet.call{value: devPay}("");
        require(developerPaySuccess, "Transfer to depeloper failed.");

        (bool marketingPaySuccess, ) = marketingWallet.call{value: marketingPay}("");
        require(marketingPaySuccess, "Transfer to depeloper failed.");

        (bool communityPaySuccess, ) = communityWallet.call{value: communityPay}("");
        require(communityPaySuccess, "Transfer to depeloper failed.");
    }

    function withdrawMoney() external onlyOwner nonReentrant {
        (bool success, ) = msg.sender.call{value: address(this).balance}("");
        require(success, "Transfer failed.");
    }

}
