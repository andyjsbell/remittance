pragma solidity 0.5.0;
import "./Running.sol";

contract Remittance is Running
{
    uint constant DEFAULT_TIMEOUT = 7 days;
    uint public depositFee;

    mapping(address => Deposit) public deposits;

    event LogDeposit(address owner, bytes32 password1, bytes32 password2, uint timeout, uint created, uint value);
    event LogTransfer(address owner, address remittant, bytes32 password1, bytes32 password2, uint256 amount);
    event LogTimeoutChanged(address owner, uint newDays, uint oldDays);
    event LogWithdraw(address owner, uint amount);

    struct Deposit
    {
        address owner;
        bytes32 password1;
        bytes32 password2;
        uint timeout;
        uint created;
        uint value;
    }

    constructor()
        Running(true)
        public
    {
    }

    modifier depositDoesNotExist(address addr)
    {
        require(deposits[addr].created == 0, 'Deposit exists');
        _;
    }

    modifier depositExists(address addr)
    {
        require(deposits[addr].created > 0, 'Invalid deposit');
        _;
    }

    function setDepositFee(uint _depositFee)
        public
        isOwner
    {
        require(depositFee != _depositFee, 'Values are equal');
        depositFee = _depositFee;
    }
    
    function isItTime(address addr)
        private
        view
        depositExists(addr)
        returns(bool)
    {
        Deposit storage deposit = deposits[addr];
        return (now - deposit.created) > deposit.timeout;
    }

    function setTimeoutInDays(uint timeout)
        public
        depositExists(msg.sender)
    {
        require(timeout > 0 && timeout < 28, 'Timeout needs to be valid');
        emit LogTimeoutChanged(msg.sender, deposits[msg.sender].timeout, timeout * 1 days);

        deposits[msg.sender].timeout = timeout * 1 days;
    }

    function deposit(bytes32 _password1, bytes32 _password2)
        public
        payable
        depositDoesNotExist(msg.sender)
    {
        // Amount deposited to contract, we need something
        require(msg.value > 0, 'Need to deposit something');

        require(_password1.length > 0 || _password2.length > 0, 'Invalid password(s)');

        uint depositValue = msg.value;
        if (depositFee < msg.value)
        {
            depositValue = msg.value - depositFee;
        }

        deposits[msg.sender] = Deposit( msg.sender,
                                        _password1,
                                        _password2,
                                        DEFAULT_TIMEOUT,
                                        now,
                                        depositValue);

        emit LogDeposit(msg.sender,
                        deposits[msg.sender].password1,
                        deposits[msg.sender].password2,
                        deposits[msg.sender].timeout,
                        deposits[msg.sender].created,
                        deposits[msg.sender].value);
    }

    function withdraw(address owner, bytes memory _password1, bytes memory _password2)
        public
        depositExists(owner)
    {
        require(keccak256(_password1) == deposits[owner].password1 &&
                keccak256(_password2) == deposits[owner].password2, 'Invalid answer');

        require(deposits[owner].value > 0, 'No balance available');
        msg.sender.transfer(deposits[owner].value);
        deposits[owner] = Deposit(  address(0x0),
                                    '',
                                    '',
                                    0,
                                    0,
                                    0);

        emit LogTransfer(   owner,
                            msg.sender,
                            deposits[owner].password1,
                            deposits[owner].password2,
                            deposits[owner].value);
    }

    function withdrawFromContract()
        public
        isOwner
    {
        msg.sender.transfer(address(this).balance);
        emit LogWithdraw(msg.sender, address(this).balance);
    }
}