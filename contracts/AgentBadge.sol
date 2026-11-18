// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title AgentGate Badge (AGB)
/// @notice Soulbound ERC-721 badge awarded by the AgentGate contract to
///         members who reach the check-in threshold.
///
/// @dev    - Minting is restricted to a single minter address (the AgentGate
///           contract), set exactly once by the owner via `setMinter`.
///         - Transfers are disabled: the badge is soulbound to the address
///           that earned it. Minting and burning remain possible; every other
///           transfer reverts.
///         - This contract never handles funds: no payable functions and no
///           transfer/approve logic beyond the (blocked) ERC-721 surface.
contract AgentBadge is ERC721, Ownable {
    /// @notice Fixed metadata served for every badge (data URI).
    string private constant _TOKEN_URI =
        "data:application/json;base64,eyJuYW1lIjoiQWdlbnRHYXRlIEJhZGdlIiwiZGVzY3JpcHRpb24iOiJTb3VsYm91bmQgYmFkZ2UgYXdhcmRlZCB0byBBZ2VudEdhdGUgbWVtYmVycyB3aXRoIDMgb3IgbW9yZSBkYWlseSBjaGVjay1pbnMuIiwiYXR0cmlidXRlcyI6W3sidHJhaXRfdHlwZSI6IlR5cGUiLCJ2YWx1ZSI6IkNoZWNrLWluIEJhZGdlIn1dfQ==";

    /// @notice The only address allowed to mint (the AgentGate contract).
    address public minter;

    uint256 private _nextTokenId = 1;

    event MinterSet(address indexed minter);

    error MinterAlreadySet();
    error NotMinter(address caller);
    error SoulboundTransfer();

    constructor(address owner_) ERC721("AgentGate Badge", "AGB") Ownable(owner_) {}

    /// @notice Set the minter (the AgentGate contract). Owner only, exactly once.
    function setMinter(address minterAddress) external onlyOwner {
        if (minter != address(0)) revert MinterAlreadySet();
        require(minterAddress != address(0), "AgentBadge: minter is zero address");
        minter = minterAddress;
        emit MinterSet(minterAddress);
    }

    /// @notice Mint the next badge to `to`. Only the minter may call this.
    /// @dev Uses `_mint` (not `_safeMint`) on purpose: the recipient is always
    ///      the member who actively claimed, and a receiver-hook check must
    ///      never lock a legitimate claimant (e.g. a smart-contract wallet)
    ///      out of a badge they earned.
    function mint(address to) external returns (uint256 tokenId) {
        if (msg.sender != minter) revert NotMinter(msg.sender);
        tokenId = _nextTokenId++;
        _mint(to, tokenId);
    }

    /// @notice The same fixed metadata URI for every badge.
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        _requireOwned(tokenId);
        return _TOKEN_URI;
    }

    /// @dev Soulbound enforcement: block every transfer where both sides are
    ///      non-zero addresses. Mint (from == address(0)) and burn
    ///      (to == address(0)) pass through.
    function _update(address to, uint256 tokenId, address auth) internal override returns (address) {
        address from = _ownerOf(tokenId);
        if (from != address(0) && to != address(0)) revert SoulboundTransfer();
        return super._update(to, tokenId, auth);
    }
}
