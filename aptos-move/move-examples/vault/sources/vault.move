module vault::core {
    use std::error;
    use std::signer;
    use aptos_std::table;
    // use std::debug;

    use aptos_framework::account;
    use aptos_framework::coin::{Self, Coin};
    use aptos_std::type_info::{Self, TypeInfo};
    use aptos_std::event::{Self, EventHandle};

    /// Event emitted when some amount of a coin is deposited into an account.
    struct DepositEvent has drop, store {
        amount: u64,
    }

    /// Event emitted when some amount of a coin is withdrawn from an account.
    struct WithdrawEvent has drop, store {
        amount: u64,
    }
    /// A holder of a specific coin types and associated event handles.
    /// These are kept in a single resource to ensure locality of data.
    struct CoinStore<phantom CoinType> has key {
        coin: Coin<CoinType>,
        frozen: bool,
        deposit_events: EventHandle<DepositEvent>,
        withdraw_events: EventHandle<WithdrawEvent>,
    }

    struct PauseCap has key {}

    struct PauseOrNot has key {
        paused: bool
    }

    // coinType address stored here with amount recorded
    struct Shares has store {
        coins: table::Table<TypeInfo, u64>,
        // signer_capability: account::SignerCapability,
    }

    struct VaultMap has key {
        shares: table::Table<address, Shares>,
    }

    const NO_CAP: u64 = 0;
    const NO_VAULT_INITIALIZED: u64 = 1;
    const NO_COIN_FOUND: u64 = 2;
    const COIN_NOT_REGISTERED: u64 = 3;
    const NO_DEPOSITS_FOUND: u64 = 4;
    const INSUFFICIENT_BALANCE: u64 = 5;
    const PAUSED: u64 = 6;

    public entry fun pause(account: &signer) acquires PauseOrNot {
        let addr = signer::address_of(account);
        assert!(exists<PauseCap>(addr), error::not_found(NO_CAP));
        borrow_global_mut<PauseOrNot>(addr).paused = true
    }

    public entry fun unpause(account: &signer) acquires PauseOrNot {
        let addr = signer::address_of(account);
        assert!(exists<PauseCap>(addr), error::not_found(NO_CAP));
        borrow_global_mut<PauseOrNot>(addr).paused = false
    }
    
    public entry fun check_pause_status(addr: address): bool acquires PauseOrNot {
        *&borrow_global<PauseOrNot>(addr).paused
    }

    public entry fun init(account: &signer) {
        move_to(account, PauseCap{});
        move_to(account, PauseOrNot {
            paused: true
        });

        move_to(account, VaultMap {
            shares: table::new<address, Shares>(),
        });
    }

    public entry fun check_balance<CoinType>(vault_addr: address, owner_addr: address): u64 acquires VaultMap {
        let VaultMap { shares } = borrow_global<VaultMap>(vault_addr);
        
        assert!(table::contains(shares, owner_addr), NO_VAULT_INITIALIZED);
        let coins = &table::borrow(shares, owner_addr).coins;
        let coin_type = type_info::type_of<CoinType>();
        assert!(table::contains(coins, coin_type), NO_COIN_FOUND);
        *table::borrow(coins, coin_type)
    }

    public entry fun register_coin<CoinType>(admin: &signer) {
        let addr = signer::address_of(admin);
        assert!(exists<PauseCap>(addr), error::not_found(NO_CAP));
        // coin::register<CoinType>(account);
        if (!exists<CoinStore<CoinType>>(addr)) {
            move_to(admin, CoinStore<CoinType> {
                coin: coin::zero(),
                deposit_events: account::new_event_handle<DepositEvent>(admin),
                withdraw_events: account::new_event_handle<WithdrawEvent>(admin),
                frozen: false
            });
        };
    }

    public entry fun deposit<CoinType>(vault_addr: address, account: &signer, value: u64) acquires VaultMap, PauseOrNot, CoinStore {
        assert!(check_pause_status(vault_addr), PAUSED);
        assert!(exists<CoinStore<CoinType>>(vault_addr), COIN_NOT_REGISTERED);

        let owner_addr = signer::address_of(account);
        let vault_map = borrow_global_mut<VaultMap>(vault_addr);
        // check if user exists in vault map, if not add user
        if (!table::contains(&vault_map.shares, owner_addr)) {
            table::add(&mut vault_map.shares, owner_addr, Shares { coins: table::new<TypeInfo, u64>() } );
        };

        // coin::transfer<CoinType>(account, vault_addr, value);
        let withdrawed_coin = coin::withdraw(account, value);
        let coin_store = borrow_global_mut<CoinStore<CoinType>>(vault_addr);
        coin::merge(&mut coin_store.coin, withdrawed_coin);

        // Record after transfer is complete to avoid drainage scenarios
        let coin_type = type_info::type_of<CoinType>();

        let coins_map = table::borrow_mut(&mut vault_map.shares, owner_addr);
        if (!table::contains(&coins_map.coins, coin_type)) {
            table::add(&mut coins_map.coins, coin_type, value);
        } else {
            let curr_amount = table::borrow_mut(&mut coins_map.coins, coin_type);
            *curr_amount = *curr_amount + value;
        };
    }

    public entry fun withdraw<CoinType>(vault_addr: address, account: &signer, value: u64) acquires VaultMap, PauseOrNot, CoinStore {
        assert!(check_pause_status(vault_addr), PAUSED);
        
        let owner_addr = signer::address_of(account);
        let vault_map = borrow_global_mut<VaultMap>(vault_addr);
        // check if user exists in vault map
        assert!(table::contains(&vault_map.shares, owner_addr), NO_DEPOSITS_FOUND);
        
        let coin_type = type_info::type_of<CoinType>();
        let coins_map = table::borrow_mut(&mut vault_map.shares, owner_addr);

        assert!(table::contains(&coins_map.coins, coin_type), NO_COIN_FOUND);
        
        let curr_amount = table::borrow_mut(&mut coins_map.coins, coin_type);

        assert!(*curr_amount >= value, INSUFFICIENT_BALANCE);

        *curr_amount = *curr_amount - value;
        let coin_store = borrow_global_mut<CoinStore<CoinType>>(vault_addr);

        event::emit_event<WithdrawEvent>(
            &mut coin_store.withdraw_events,
            WithdrawEvent { amount: value },
        );

        let withdrawed_coin = coin::extract(&mut coin_store.coin, value);
        coin::deposit<CoinType>(owner_addr, withdrawed_coin);
    }
}
