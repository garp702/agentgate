// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @notice Minimal view of the Binance Agent ID registry (SPACE ID, ERC-721).
/// @dev Production registry on BNB Chain: 0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F
interface IAgentIdRegistry {
    function balanceOf(address owner) external view returns (uint256);
}

/// @notice Minimal interface of the AgentGate badge contract.
interface IAgentBadge {
    function mint(address to) external returns (uint256 tokenId);
}

/// @title AgentGate
/// @notice A members-only daily check-in gate for Binance Agent ID holders.
///
///         Agent ID is the core of the product flow: every interaction starts
///         with an on-chain check that the caller currently holds an Agent ID
///         (registry.balanceOf(caller) > 0). Holders check in once per UTC day,
///         building a streak; after BADGE_THRESHOLD lifetime check-ins they can
///         claim a soulbound badge NFT.
///
/// @dev    SAFETY / PERMISSIONS MODEL (also disclosed in README.md):
///         - This contract NEVER handles funds: there are no payable functions,
///           no deposit/withdraw/transfer/approve logic of any kind. Users only
///           ever pay their own gas for their own transactions.
///         - The owner (deployer) has NO power over user records. There is no
///           setter that can create, edit, or delete any member's check-in
///           stats, membership, streak, or badge-claim status. The owner's only
///           capability is the one-time wiring call `setBadge`, which points
///           the gate at its badge contract before use and can never be changed
///           afterwards.
contract AgentGate is Ownable {
    /// @notice Number of lifetime check-ins required to claim the badge.
    uint256 public constant BADGE_THRESHOLD = 3;

    uint256 private constant SECONDS_PER_DAY = 86400;

    /// @notice The Agent ID registry this gate checks membership against.
    IAgentIdRegistry public immutable agentIdRegistry;

    /// @notice The badge contract, wired exactly once by the owner.
    IAgentBadge public badge;

    struct MemberStats {
        uint256 totalCheckIns;
        uint256 streak;
        uint256 lastCheckInDay;
        uint256 memberSince; // block.timestamp of first check-in; 0 = not a member
        bool badgeClaimed;
    }

    mapping(address => MemberStats) private _stats;

    uint256 private _uniqueMembers;

    event CheckedIn(address indexed user, uint256 day, uint256 streak, uint256 total);
    event BadgeClaimed(address indexed user, uint256 tokenId);
    event BadgeSet(address indexed badge);

    error NoAgentId(address user);
    error AlreadyCheckedInToday(address user, uint256 day);
    error NotMember(address user);
    error BadgeThresholdNotMet(address user, uint256 totalCheckIns, uint256 required);
    error BadgeAlreadyClaimed(address user);
    error BadgeNotConfigured();
    error BadgeAlreadySet();

    /// @param registry Address of the Agent ID registry (ERC-721).
    ///        Production: 0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F
    constructor(address registry, address owner_) Ownable(owner_) {
        require(registry != address(0), "AgentGate: registry is zero address");
        agentIdRegistry = IAgentIdRegistry(registry);
    }

    /// @notice One-time wiring: set the badge contract. Owner only, callable
    ///         exactly once, and it cannot touch any user record.
    function setBadge(address badgeAddress) external onlyOwner {
        if (address(badge) != address(0)) revert BadgeAlreadySet();
        require(badgeAddress != address(0), "AgentGate: badge is zero address");
        badge = IAgentBadge(badgeAddress);
        emit BadgeSet(badgeAddress);
    }

    // ------------------------------------------------------------------
    // Views
    // ------------------------------------------------------------------

    /// @notice True if `user` currently holds at least one Agent ID.
    function hasAgentId(address user) public view returns (bool) {
        return agentIdRegistry.balanceOf(user) > 0;
    }

    /// @notice True if `user` has ever checked in (is a registered member).
    function isMember(address user) public view returns (bool) {
        return _stats[user].memberSince != 0;
    }

    /// @notice Full check-in stats for `user`.
    function statsOf(address user)
        external
        view
        returns (uint256 totalCheckIns, uint256 streak, uint256 lastCheckInDay, uint256 memberSince)
    {
        MemberStats storage s = _stats[user];
        return (s.totalCheckIns, s.streak, s.lastCheckInDay, s.memberSince);
    }

    /// @notice Number of unique addresses that have ever checked in.
    function uniqueMembers() external view returns (uint256) {
        return _uniqueMembers;
    }

    /// @notice Lifetime check-ins required before a member can claim the badge.
    function badgeThreshold() external pure returns (uint256) {
        return BADGE_THRESHOLD;
    }

    // ------------------------------------------------------------------
    // Core flow
    // ------------------------------------------------------------------

    /// @notice Check in for today (UTC). Caller must currently hold an Agent ID.
    /// @dev    One check-in per address per UTC day. The streak increments when
    ///         the previous check-in was yesterday, and resets to 1 when a day
    ///         was skipped. The first ever check-in registers the caller as a
    ///         member and increments the unique-member counter exactly once.
    function checkIn() external {
        if (!hasAgentId(msg.sender)) revert NoAgentId(msg.sender);

        uint256 today = block.timestamp / SECONDS_PER_DAY;
        MemberStats storage s = _stats[msg.sender];

        if (s.memberSince != 0) {
            if (s.lastCheckInDay == today) revert AlreadyCheckedInToday(msg.sender, today);
            // Consecutive day extends the streak; any gap resets it to 1.
            s.streak = (s.lastCheckInDay == today - 1) ? s.streak + 1 : 1;
        } else {
            // First ever check-in: register membership exactly once.
            s.memberSince = block.timestamp;
            s.streak = 1;
            _uniqueMembers += 1;
        }

        s.lastCheckInDay = today;
        s.totalCheckIns += 1;

        emit CheckedIn(msg.sender, today, s.streak, s.totalCheckIns);
    }

    /// @notice Claim the soulbound badge. Requires membership and at least
    ///         BADGE_THRESHOLD lifetime check-ins. One badge per address, ever.
    /// @return tokenId The id of the minted badge.
    function claimBadge() external returns (uint256 tokenId) {
        MemberStats storage s = _stats[msg.sender];

        if (s.memberSince == 0) revert NotMember(msg.sender);
        if (s.badgeClaimed) revert BadgeAlreadyClaimed(msg.sender);
        if (s.totalCheckIns < BADGE_THRESHOLD) {
            revert BadgeThresholdNotMet(msg.sender, s.totalCheckIns, BADGE_THRESHOLD);
        }
        if (address(badge) == address(0)) revert BadgeNotConfigured();

        // Effects before interaction.
        s.badgeClaimed = true;

        tokenId = badge.mint(msg.sender);
        emit BadgeClaimed(msg.sender, tokenId);
    }
}
