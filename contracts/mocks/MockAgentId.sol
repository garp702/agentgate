// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title MockAgentId
/// @notice Tiny stand-in for the Agent ID registry, for LOCAL TESTS ONLY.
/// @dev    Not a real ERC-721: it only implements the `balanceOf` surface that
///         AgentGate reads, plus test helpers to grant/revoke a fake Agent ID.
///         Never deploy this anywhere near production.
contract MockAgentId {
    mapping(address => uint256) private _balances;

    function balanceOf(address owner) external view returns (uint256) {
        return _balances[owner];
    }

    /// @notice Test helper: give `to` one (more) Agent ID.
    function grant(address to) external {
        _balances[to] += 1;
    }

    /// @notice Test helper: remove one Agent ID from `from`
    ///         (simulates losing / burning / transferring away the ID).
    function revoke(address from) external {
        require(_balances[from] > 0, "MockAgentId: nothing to revoke");
        _balances[from] -= 1;
    }
}
