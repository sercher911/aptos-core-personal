module vault::core {
    use std::error;
    use std::signer;
    use aptos_std::table;
    use aptos_framework::coin;
    use aptos_std::type_info;

    struct Coin<phantom CoinType> has store {
        /// Amount of coin this address has.
        value: u64,
    }

    struct PauseCap has key {}

    struct PauseOrNot has key {
        paused: bool
    }

    // coinType address stored here with amount recorded
    struct Shares has store {
        coins: table::Table<address, u64>
    }

    struct VaultMap has key {
        shares: table::Table<address, Shares>,
    }

    const NO_CAP: u64 = 0;
    const NO_VAULT_INITIALIZED: u64 = 1;
    const NO_COIN_FOUND: u64 = 2;
    const COIN_NOT_REGISTERED: u64 = 3;

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
            // balances: vector::empty<Coin<CoinType>>()
        });
    }

    public entry fun check_balance<CoinType>(vault_addr: address, owner_addr: address): u64 acquires VaultMap {
        let VaultMap { shares } = borrow_global<VaultMap>(vault_addr);
        assert!(table::contains(shares, owner_addr), NO_VAULT_INITIALIZED);
        let coins = &table::borrow(shares, owner_addr).coins;
        let coin_addr = coin_address<CoinType>();
        assert!(table::contains(coins, coin_addr), NO_COIN_FOUND);
        *table::borrow(coins, coin_addr)
    }

    public entry fun register_coin<CoinType>(account: &signer) {
        let addr = signer::address_of(account);
        assert!(exists<PauseCap>(addr), error::not_found(NO_CAP));
        coin::register<CoinType>(account);
    }

    public entry fun deposit<CoinType>(vault_addr: address, account: &signer, value: u64) acquires VaultMap {
        // coin is not registered!
        // assert!(!coin::is_account_registered<CoinType>(vault_addr), COIN_NOT_REGISTERED);

        let owner_addr = signer::address_of(account);
        let vault_map = borrow_global_mut<VaultMap>(vault_addr);
        // check if user exists in vault map, if not add user
        if (!table::contains(&vault_map.shares, owner_addr)) {
            table::add(&mut vault_map.shares, owner_addr, Shares { coins: table::new<address, u64>() } );
        };

        coin::transfer<CoinType>(account, vault_addr, value);

        // Record after transfer is complete to avoid drainage scenarios
        let coin_addr = coin_address<CoinType>();

        let coins_map = table::borrow_mut(&mut vault_map.shares, owner_addr);
        if (!table::contains(&coins_map.coins, coin_addr)) {
            table::add(&mut coins_map.coins, coin_addr, value);
        } else {
            let curr_amount = table::borrow_mut(&mut coins_map.coins, coin_addr);
            *curr_amount = *curr_amount + value;
        };
    }

    // /// A helper function that returns the address of CoinType.
    public fun coin_address<CoinType>(): address {
        let type_info = type_info::type_of<CoinType>();
        type_info::account_address(&type_info)
    }

    // public fun withdraw<T>(to: &signer, amount: u64) {
    //     let coin = coin::withdraw(from, amount);
    //     coin::deposit(to, coin);
    // }

    // public entry fun set_message(account: signer, message: string::String)
    // acquires MessageHolder {
    //     let account_addr = signer::address_of(&account);
    //     if (!exists<MessageHolder>(account_addr)) {
    //         move_to(&account, MessageHolder {
    //             message,
    //             message_change_events: account::new_event_handle<MessageChangeEvent>(&account),
    //         })
    //     } else {
    //         let old_message_holder = borrow_global_mut<MessageHolder>(account_addr);
    //         let from_message = *&old_message_holder.message;
    //         event::emit_event(&mut old_message_holder.message_change_events, MessageChangeEvent {
    //             from_message,
    //             to_message: copy message,
    //         });
    //         old_message_holder.message = message;
    //     }
    // }

    // #[test(account = @0x1)]
    // public entry fun sender_can_set_message(account: signer) acquires MessageHolder {
    //     let addr = signer::address_of(&account);
    //     aptos_framework::account::create_account_for_test(addr);
    //     set_message(account,  string::utf8(b"Hello, Blockchain"));

    //     assert!(
    //       get_message(addr) == string::utf8(b"Hello, Blockchain"),
    //       ENO_MESSAGE
    //     );
    // }
}
