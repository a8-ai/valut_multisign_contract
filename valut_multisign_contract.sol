// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);

    function transferFrom(address from, address to, uint256 amount) external returns (bool);

    function balanceOf(address account) external view returns (uint256);
}

// Multi-signature contract
// 多重簽章合約
contract MultiSignContract {
    address private owner;
    address[] private members;
    mapping(address => bool) private isMember;
    uint256 private required;

    // A8 counter address, Hard-coded and unchangeable
    // A8櫃檯地址，採用硬編碼形式，不可更改
    address public whiteAddress = address("TXDQhqABC7tCPkWray4153Njwojja8a8a8");

    struct Transaction {
        address to;
        uint256 value;
        address tokenAddress;
        bool executed;
        uint256 confirmations;
    }

    Transaction[] private transactions;
    mapping(uint256 => mapping(address => bool)) private isConfirmed;

    event Deposit(address sender, uint256 amount);
    event Submit(uint256 txIndex, address tokenAddress);
    event Confirm(address member, uint256 txIndex);
    event Execute(uint256 txIndex);
    event MembersAdded(address[] newMembers);
    event MembersRemoved(address removeMember);

    modifier onlyMember() {
        require(isMember[msg.sender], "!member");
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "!owner");
        _;
    }

    constructor(address[] memory _members, address _white) {
        require(_members.length >= 3, "min 3");
        owner = msg.sender;
        whiteAddress = _white;

        for (uint256 i = 0; i < _members.length; i++) {
            isMember[_members[i]] = true;
            members.push(_members[i]);
        }

        // Multi-signature member 2/3 approval
        // 多簽成員 2/3 通過
        required = (_members.length * 2 + 2) / 3;
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value);
    }

    fallback() external payable {
        emit Deposit(msg.sender, msg.value);
    }

    function submit(address _to, uint256 _value) external onlyOwner {
        transactions.push(Transaction({
            to: _to,
            value: _value,
            tokenAddress: address(0),
            executed: false,
            confirmations: 0
        }));
        emit Submit(transactions.length - 1, address(0));
    }

    function submitToken(address _to, uint256 _value, address _tokenAddress) external onlyOwner {
        require(_tokenAddress != address(0), "Invalid token");
        transactions.push(Transaction({
            to: _to,
            value: _value,
            tokenAddress: _tokenAddress,
            executed: false,
            confirmations: 0
        }));
        emit Submit(transactions.length - 1, _tokenAddress);
    }

    // Multi-signature member confirmation
    // 多簽成員確認
    function confirm(uint256 _txIndex) external onlyMember {
        require(_txIndex < transactions.length, "Invalid tx index");
        require(!isConfirmed[_txIndex][msg.sender], "confirmed");
        require(!transactions[_txIndex].executed, "executed");

        Transaction storage t = transactions[_txIndex];
        t.confirmations++;
        isConfirmed[_txIndex][msg.sender] = true;
        emit Confirm(msg.sender, _txIndex);

        if (t.confirmations >= required) {
            t.executed = true;

            if (t.tokenAddress == address(0)) {
                payable(t.to).transfer(t.value);
            } else {
                IERC20(t.tokenAddress).transfer(t.to, t.value);
            }

            emit Execute(_txIndex);
        }
    }

    function toWhiteAddress(uint256 amount) external onlyOwner {
        payable(whiteAddress).transfer(amount);
    }

    function tokenToWhiteAddress(uint256 amount, address tokenAddress) external onlyOwner {
        require(tokenAddress != address(0), "Invalid token");
        IERC20(tokenAddress).transfer(whiteAddress, amount);
    }

    function getTokenBalance(address tokenAddress) external view returns (uint256) {
        return IERC20(tokenAddress).balanceOf(address(this));
    }

    function getTransaction(uint256 _txIndex) external view returns (
        address to,
        uint256 value,
        address tokenAddress,
        bool executed,
        bool ownerConfirmed,
        uint256 confirmations
    ) {
        require(_txIndex < transactions.length, "Invalid tx index");
        Transaction storage t = transactions[_txIndex];
        return (
            t.to,
            t.value,
            t.tokenAddress,
            t.executed,
            t.ownerConfirmed,
            t.confirmations
        );
    }

    // Add multi-signature members
    // 新增多簽成員
    function addSignMembers(address[] memory newMembers) external onlyOwner {
        require(newMembers.length > 0, "Empty array");

        for (uint256 i = 0; i < newMembers.length; i++) {
            address newMember = newMembers[i];
            require(newMember != address(0), "Invalid address");
            require(!isMember[newMember], "Already member");

            isMember[newMember] = true;
            members.push(newMember);
        }

        // Multi-signature member 2/3 approval
        // 多簽成員 2/3 通過
        required = (members.length * 2 + 2) / 3;

        emit MembersAdded(newMembers);
    }

    // Remove multi-signature members
    // 移除多簽成員
    function removeSignMember(address _member) public onlyOwner {
        require(isMember[_member], "Address is not a member");
        require(members.length > 1, "Cannot remove the last member");
        require(required <= members.length - 1, "Required confirmations would exceed remaining members");

        for (uint i = 0; i < members.length; i++) {
            if (members[i] == _member) {
                if (i < members.length - 1) {
                    members[i] = members[members.length - 1];
                }
                members.pop();
                isMember[_member] = false;
                break;
            }
        }

        // Multi-signature member 2/3 approval
        // 多簽成員 2/3 通過
        required = (members.length * 2 + 2) / 3;

        emit MembersRemoved(_member);
    }

    // Get the list of multi-signature members
    // 取得多簽成員清單
    function getSignMembers() external view returns (address[] memory) {
        return members;
    }
}
