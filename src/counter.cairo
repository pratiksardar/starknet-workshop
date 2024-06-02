#[starknet::interface]
trait ICounter<T> {
    fn get_counter(self: @T) -> u32;
    fn increase_counter(ref self: T);
}


#[starknet::contract]
mod Counter {
    use openzeppelin::access::ownable::ownable::OwnableComponent::InternalTrait;
    use super::ICounter;
    use starknet::ContractAddress;
    use kill_switch::IKillSwitchDispatcher;
    use kill_switch::IKillSwitchDispatcherTrait;
    use openzeppelin::access::ownable::OwnableComponent;


    component!(path: OwnableComponent, storage: ownable, event: OEvent);

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        CounterIncreased: CounterIncreased,
        OEvent: OwnableComponent::Event,
    }

    #[derive(Drop, starknet::Event)]
    struct CounterIncreased {
        #[key]
        counter: u32,
    }

    #[storage]
    struct Storage {
        counter: u32,
        ks_address: ContractAddress,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
    }

    #[constructor]
    fn constructor(ref self: ContractState, value: u32, ks_address: ContractAddress, initial_owner: ContractAddress) {
        self.counter.write(value);
        self.ks_address.write(ks_address);
        self.ownable.initializer(initial_owner);
    }

    #[abi(embed_v0)]
    impl ImplCounter of ICounter<ContractState> {
        fn get_counter(self: @ContractState) -> u32 {
            self.counter.read()
        }

        fn increase_counter(ref self: ContractState) {
            let mut val = self.counter.read();
            let ks_address = self.ks_address.read();
            if (IKillSwitchDispatcher { contract_address: ks_address }.is_active()) {
                panic!("Kill Switch is active");
            } else {
                self.ownable.assert_only_owner();
                val = val + 1;
                self.counter.write(val);
                let event = CounterIncreased { counter: val };
                self.emit(event);
            }
        }
    }
}
