// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./TransferHelper.sol";

contract MyToken is ERC721URIStorage, Ownable, Initializable, ReentrancyGuard {
    using Strings for uint256;
    
    IERC721 public constant EXCHANGE_NFT = IERC721(0xCd76D0Cf64Bf4A58D898905C5adAD5e1E838E0d3);
    
    string public baseURI;
    string public baseExtension = ".json";

    bool public isSaleActive;
    bool public revealed;
    
    uint public TOTAL_SUPPLY = 8888;
    uint256 public _totalSupply;

    MintingPhase public phase;

    mapping(address => bool) public whitelisted;
    mapping(address => bool) public blacklisted; 
    mapping(uint256 => bool) public usedNFTs;

    uint256 public whitelistPrice;
    uint256 public publicPrice;
    
    enum MintingPhase {
        Exchange, 
        Whitelist, 
        Public
    }

    modifier blacklist(address recipient) {
        require(!blacklisted[recipient], "Recipient is blacklisted!");

        _;
    }

    constructor(string memory name, string memory symbol, string memory _baseURI)
        ERC721(name, symbol)
    {}

    function mint(uint256 tokenId, address to, string memory uri) external payable nonReentrant {
        require(isSaleActive, "The sale is not active");
        require(_totalSupply <= TOTAL_SUPPLY, "total supply overflow");

        if(phase == MintingPhase.Exchange) {
            require(msg.sender == EXCHANGE_NFT.ownerOf(tokenId), "You are not the owner of the NFT");
            require(!usedNFTs[tokenId], "The NFT has already been used");

            usedNFTs[tokenId] = true;
            _safeMintInternal(to, uri);
        } else if(phase == MintingPhase.Whitelist) {
            require(whitelisted[msg.sender], "The whitelist is missing");
            require(msg.value == whitelistPrice, "Insufficient funds");

            whitelisted[msg.sender] = false;

            _safeMintInternal(to, uri);

        } else {
            require(msg.value == publicPrice, "Insufficient funds");

            _safeMintInternal(to, uri);
        }
    }

    function _safeMintInternal(address to, string memory uri) internal {
        uint256 _tokenId = _totalSupply++;
        _safeMint(to, _tokenId);
        _setTokenURI(_tokenId, uri);

        _totalSupply++;
    }

    function transferFrom(address from, address to, uint256 tokenId) public override(ERC721, IERC721) blacklist(to) {
        super.transferFrom(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) public override(ERC721, IERC721) blacklist(to) {
        super.safeTransferFrom(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) public override(ERC721, IERC721) blacklist(to) {
        super.safeTransferFrom(from, to, tokenId, data);
    }
    
    // Owner-only functions
    function reveal(string memory _newBaseURI) external onlyOwner {
        baseURI = _newBaseURI;
        revealed = true;
    }

    // Owner-only functions
    function withdrawETH() external onlyOwner {
        TransferHelper.safeTransferETH(msg.sender, address(this).balance);
    }

    // Owner-only functions
    function setWhitelist(address[] calldata users, bool action) external onlyOwner {
        uint256 usersLength = users.length;

        for(uint256 i; i < usersLength; ) {
            whitelisted[users[i]] = action;

            unchecked {
                ++i;
            }
        }
    } 

    // Owner-only functions
    function setBlacklist(address[] calldata users, bool action) external onlyOwner {
        uint256 usersLength = users.length;

        for(uint256 i; i < usersLength; ) {
            blacklisted[users[i]] = action;

            unchecked {
                ++i;
            }
        }
    } 

    // Owner-only functions
    function flipSaleState() external onlyOwner {
        isSaleActive = !isSaleActive;
    }
    
    // Owner-only functions
    function updateWhitelistPrice(uint256 price) external onlyOwner {
        whitelistPrice = price;
    }
    
    // Owner-only functions
    function updatePublicPrice(uint256 price) external onlyOwner {
        publicPrice = price;
    } 

    // Owner-only functions
    function changeMintingPhase(MintingPhase _phase) external onlyOwner {
        phase = _phase;
    }
    
    // Owner-only functions
    function slashingTotalSupply() external initializer onlyOwner {
        TOTAL_SUPPLY = 4444; 
    }

    // The following functions are overrides required by Solidity.

    function totalSupply() external view returns(uint256) {
        return _totalSupply;
    }

    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
  {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
    
        if(!revealed) {
            return "ipfs://QmbMYusHbqFujnrT3HjJjLk9fq62YWQTsBe2Pbz1JTVytf";
        }

        return string(abi.encodePacked(baseURI, tokenId.toString(), baseExtension));
  }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721URIStorage)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
