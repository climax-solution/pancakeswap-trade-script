private_key = "";
require "eth"; # Ruby library and RPC-client to handle Ethereum accounts, messages, and transactions
require "forwardable"; # Ruby library to provide delegation of specified methods to a designated object, using the methods
require "json"; 

router_abi_file = File.read("./router_abi.json"); # router_abi.json - pancakeswap router v2 abi code
router_abi_code = JSON.parse(router_abi_file);

token_abi_file = File.read("./token_abi.json"); # token_abi.json - ERC20 token abi code
token_abi_code = JSON.parse(token_abi_file);

$router_addr = "0x9ac64cc6e4415144c455bd8e4837fea55603e5c3"; # pancakeswap router v2 smart contract address
$token_addr = "0xaB1a4d4f1D656d2450692D237fdD6C7f9146e814"; # BUSD token smart contract address

$provider = Eth::Client.create "https://data-seed-prebsc-1-s1.binance.org:8545/" # init RPC client for BSC testnet
$account = Eth::Key.new priv: private_key; # create wallet with private key
$router_contract = Eth::Contract.from_abi(abi: router_abi_code, address: $router_addr, name: "PancakeRouter"); # init router smart contract with abi code, contract address, and name
$token_contract = Eth::Contract.from_abi(abi: token_abi_code, address: $token_addr, name: "MockToken"); # init token smart contract like above
$WBNB_address = $provider.call($router_contract, "WETH"); # get WBNB address
$path1 = [$WBNB_address, $token_addr]; # path to swap from BNB to BUSD
$path2 = [$token_addr, $WBNB_address]; # path to swap from BUSD to BNB

def buy(amount)
    puts "Swapping . . .";
    
    amountIn = amount.to_f * 10 ** 18;
    balance = $provider.get_balance(Eth::Address.new $account.address.to_s); # check wallet's BNB balance
    if amountIn >= balance
        puts "Insufficient funds";
        return;
    end

    amountOutMin = $provider.call($router_contract, "getAmountsOut", amountIn, $path1); # calculate expected BUSD amount
    puts "Expected Token Amount(Wei):", amountOutMin[1];

    deadline = Time.now.to_i * 1000 + 60 * 1000;

    tx = $provider.transact_and_wait(
        $router_contract,
        "swapETHForExactTokens",
        amountOutMin[1],
        $path1,
        $account.address.to_s,
        deadline,
        **{
            tx_value: amountIn,
            sender_key: $account,
            legacy: true,
            gas_limit: 25_0000
        }
    ); # send transaction

    if tx
        puts "Buy BUSD successfully", tx;
    else
        puts "Failed"
    end
end

def sell(amount)
    puts "Approving Tokens. . .";
    
    amountIn = amount.to_f * 10 ** 18;
    balance = $provider.call($token_contract, "balanceOf", $account.address.to_s); # check wallet's BUSD balance
    if amountIn >= balance
        puts "Insufficient funds";
        return;
    end

    $provider.transact_and_wait(
        $token_contract,
        "approve",
        $router_addr,
        amountIn,
        **{
            sender_key: $account,
            legacy: true,
            gas_limit: 25_0000
        }
    ); # approve router contract to send token

    puts "Approved";

    amountOutMin = $provider.call($router_contract, "getAmountsOut", amountIn, $path2); # calculate expected BNB amount
    puts "Expected BNB Amount(Wei):", amountOutMin[1];

    deadline = Time.now.to_i * 1000 + 60 * 1000;
    
    puts "Swapping . . .";
    tx = $provider.transact(
        $router_contract,
        "swapExactTokensForETH",
        amountIn,
        amountOutMin[1],
        $path2,
        $account.address.to_s,
        deadline,
        **{
            sender_key: $account,
            legacy: true,
            gas_limit: 25_0000
        }
    ); # send transaction
    
    if tx
        puts "Sel BUSD successfully", tx;
    else
        puts "Failed"
    end

end

if ARGV.length == 2 # get arguments from command line, 0: function type, 1: coin amount
    if ARGV[0] == "buy"
        buy ARGV[1];
    elsif ARGV[0] == "sell"
        sell ARGV[1];
    else
        puts "Enter parameter correctly"
    end
end