// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {AgentGate} from "../contracts/AgentGate.sol";
import {AgentBadge} from "../contracts/AgentBadge.sol";
import {MockAgentId} from "../contracts/mocks/MockAgentId.sol";

contract AgentGateTest is Test {
    MockAgentId internal registry;
    AgentGate internal gate;
    AgentBadge internal badge;

    address internal alice = makeAddr("alice"); // Agent ID holder
    address internal carol = makeAddr("carol"); // Agent ID holder
    address internal bob = makeAddr("bob"); // no Agent ID

    uint256 internal dayZero; // timestamp of 00:00 UTC of the start day

    function setUp() public {
        registry = new MockAgentId();
        gate = new AgentGate(address(registry), address(this));
        badge = new AgentBadge(address(this));

        // Wire badge <-> gate exactly as in production deployment.
        badge.setMinter(address(gate));
        gate.setBadge(address(badge));

        registry.grant(alice);
        registry.grant(carol);

        // Start at 01:00 UTC of a fixed day so day arithmetic is unambiguous.
        uint256 startTs = 1_700_000_000;
        dayZero = (startTs / 86400) * 86400;
        vm.warp(dayZero + 3600);
    }

    /// @dev Move to 01:00 UTC of day `n` (0 = start day).
    function _goToDay(uint256 n) internal {
        vm.warp(dayZero + n * 86400 + 3600);
    }

    function _checkInAs(address user, uint256 day) internal {
        _goToDay(day);
        vm.prank(user);
        gate.checkIn();
    }

    // ----------------------------------------------------------------
    // checkIn: gating
    // ----------------------------------------------------------------

    function test_NonHolderCheckInReverts() public {
        assertFalse(gate.hasAgentId(bob));
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(AgentGate.NoAgentId.selector, bob));
        gate.checkIn();
    }

    function test_HolderCheckInSucceedsAndStatsUpdate() public {
        assertTrue(gate.hasAgentId(alice));
        assertFalse(gate.isMember(alice));

        vm.expectEmit(true, false, false, true, address(gate));
        emit AgentGate.CheckedIn(alice, block.timestamp / 86400, 1, 1);
        vm.prank(alice);
        gate.checkIn();

        (uint256 total, uint256 streak, uint256 lastDay, uint256 memberSince) = gate.statsOf(alice);
        assertEq(total, 1);
        assertEq(streak, 1);
        assertEq(lastDay, block.timestamp / 86400);
        assertEq(memberSince, block.timestamp);
        assertTrue(gate.isMember(alice));
        assertEq(gate.uniqueMembers(), 1);
    }

    function test_SecondCheckInSameDayReverts() public {
        _checkInAs(alice, 0);

        // Later the same UTC day: still rejected.
        vm.warp(dayZero + 3600 + 7200);
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(AgentGate.AlreadyCheckedInToday.selector, alice, block.timestamp / 86400)
        );
        gate.checkIn();
    }

    function test_NextDayCheckInIncrementsStreak() public {
        _checkInAs(alice, 0);
        _checkInAs(alice, 1);

        (uint256 total, uint256 streak,,) = gate.statsOf(alice);
        assertEq(total, 2);
        assertEq(streak, 2);
    }

    function test_SkippedDayResetsStreakToOne() public {
        _checkInAs(alice, 0);
        _checkInAs(alice, 1);

        // Day 2 is skipped entirely; next check-in lands on day 3.
        _checkInAs(alice, 3);

        (uint256 total, uint256 streak, uint256 lastDay,) = gate.statsOf(alice);
        assertEq(total, 3);
        assertEq(streak, 1);
        assertEq(lastDay, (dayZero + 3 * 86400 + 3600) / 86400);
    }

    function test_UniqueMembersCountsEachAddressOnce() public {
        _checkInAs(alice, 0);
        _checkInAs(alice, 1);
        _checkInAs(alice, 2);
        assertEq(gate.uniqueMembers(), 1);

        _checkInAs(carol, 2);
        _checkInAs(carol, 3);
        assertEq(gate.uniqueMembers(), 2);
    }

    function test_LosingAgentIdBlocksCheckIn() public {
        _checkInAs(alice, 0);

        // Alice loses her Agent ID (mock revoke = burn/transfer away).
        registry.revoke(alice);
        assertFalse(gate.hasAgentId(alice));

        _goToDay(1);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(AgentGate.NoAgentId.selector, alice));
        gate.checkIn();
    }

    // ----------------------------------------------------------------
    // Badge claiming
    // ----------------------------------------------------------------

    function test_BadgeThresholdIsThree() public view {
        assertEq(gate.badgeThreshold(), 3);
    }

    function test_BadgeClaimByNonMemberReverts() public {
        registry.grant(bob); // holder, but never checked in -> not a member
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(AgentGate.NotMember.selector, bob));
        gate.claimBadge();
    }

    function test_BadgeClaimBeforeThresholdReverts() public {
        _checkInAs(alice, 0);
        _checkInAs(alice, 1); // total = 2 < 3

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(AgentGate.BadgeThresholdNotMet.selector, alice, 2, 3)
        );
        gate.claimBadge();
    }

    function test_BadgeClaimAtThresholdMintsExactlyOne() public {
        _checkInAs(alice, 0);
        _checkInAs(alice, 1);
        _checkInAs(alice, 2); // total = 3 = threshold

        vm.prank(alice);
        uint256 tokenId = gate.claimBadge();

        assertEq(badge.balanceOf(alice), 1);
        assertEq(badge.ownerOf(tokenId), alice);
        assertTrue(bytes(badge.tokenURI(tokenId)).length > 0);

        // Second claim reverts; still exactly one badge.
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(AgentGate.BadgeAlreadyClaimed.selector, alice));
        gate.claimBadge();
        assertEq(badge.balanceOf(alice), 1);
    }

    function test_BadgeTransferRevertsSoulbound() public {
        _checkInAs(alice, 0);
        _checkInAs(alice, 1);
        _checkInAs(alice, 2);
        vm.prank(alice);
        uint256 tokenId = gate.claimBadge();

        vm.prank(alice);
        vm.expectRevert(AgentBadge.SoulboundTransfer.selector);
        badge.transferFrom(alice, carol, tokenId);

        vm.prank(alice);
        vm.expectRevert(AgentBadge.SoulboundTransfer.selector);
        badge.safeTransferFrom(alice, carol, tokenId);

        // Ownership unchanged.
        assertEq(badge.ownerOf(tokenId), alice);
    }

    function test_DirectBadgeMintByNonMinterReverts() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(AgentBadge.NotMinter.selector, alice));
        badge.mint(alice);
    }

    // ----------------------------------------------------------------
    // Wiring / owner surface
    // ----------------------------------------------------------------

    function test_MinterAndBadgeCanOnlyBeSetOnce() public {
        vm.expectRevert(AgentBadge.MinterAlreadySet.selector);
        badge.setMinter(address(0xBEEF));

        vm.expectRevert(AgentGate.BadgeAlreadySet.selector);
        gate.setBadge(address(0xBEEF));
    }

    function test_BadgeMetadata() public view {
        assertEq(badge.name(), "AgentGate Badge");
        assertEq(badge.symbol(), "AGB");
    }

    // The production deploy goes through a CREATE2 factory, so the owner
    // must be the explicit constructor argument — never the deployer.
    function test_ExplicitOwnerSurvivesFactoryStyleDeploy() public {
        address alice = makeAddr("alice");
        AgentGate g2 = new AgentGate(address(registry), alice);
        AgentBadge b2 = new AgentBadge(alice);
        assertEq(g2.owner(), alice);
        assertEq(b2.owner(), alice);

        // The deployer (this contract) has no wiring power.
        vm.expectRevert();
        g2.setBadge(address(b2));
        vm.expectRevert();
        b2.setMinter(address(g2));

        // The named owner does.
        vm.prank(alice);
        g2.setBadge(address(b2));
        vm.prank(alice);
        b2.setMinter(address(g2));
    }
}
