enum OrderStatus {
  pending,
  preparing,
  ready,
  completed;

  String get displayName {
    switch (this) {
      case OrderStatus.pending:
        return 'Pending';
      case OrderStatus.preparing:
        return 'Preparing';
      case OrderStatus.ready:
        return 'Ready';
      case OrderStatus.completed:
        return 'Completed';
    }
  }
}

class OrderItem {
  final String name;
  final int quantity;
  final double price;

  const OrderItem({
    required this.name,
    required this.quantity,
    required this.price,
  });

  OrderItem copyWith({
    String? name,
    int? quantity,
    double? price,
  }) {
    return OrderItem(
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
    );
  }
}

class RestaurantOrder {
  final String id;
  final OrderStatus status;
  final String locationLabel;
  final String? locationValue;
  final String typeLabel;
  final String? typeValue;
  final String time;
  final String serverName;
  final String workTime;
  final double workTimeProgress;
  final List<OrderItem> items;
  final double totalAmount;

  const RestaurantOrder({
    required this.id,
    required this.status,
    required this.locationLabel,
    this.locationValue,
    required this.typeLabel,
    this.typeValue,
    required this.time,
    required this.serverName,
    required this.workTime,
    required this.workTimeProgress,
    required this.items,
    required this.totalAmount,
  });

  RestaurantOrder copyWith({
    String? id,
    OrderStatus? status,
    String? locationLabel,
    String? locationValue,
    String? typeLabel,
    String? typeValue,
    String? time,
    String? serverName,
    String? workTime,
    double? workTimeProgress,
    List<OrderItem>? items,
    double? totalAmount,
  }) {
    return RestaurantOrder(
      id: id ?? this.id,
      status: status ?? this.status,
      locationLabel: locationLabel ?? this.locationLabel,
      locationValue: locationValue ?? this.locationValue,
      typeLabel: typeLabel ?? this.typeLabel,
      typeValue: typeValue ?? this.typeValue,
      time: time ?? this.time,
      serverName: serverName ?? this.serverName,
      workTime: workTime ?? this.workTime,
      workTimeProgress: workTimeProgress ?? this.workTimeProgress,
      items: items ?? this.items,
      totalAmount: totalAmount ?? this.totalAmount,
    );
  }

  static List<RestaurantOrder> getSampleOrders() {
    return [
      RestaurantOrder(
        id: 'Order 002',
        status: OrderStatus.preparing,
        locationLabel: 'VIP Room',
        locationValue: '08',
        typeLabel: 'Guests',
        typeValue: '12',
        time: '2:34',
        serverName: 'John doe',
        workTime: '08:12',
        workTimeProgress: 0.72,
        items: const [
          OrderItem(name: 'Loster Thermidor', quantity: 2, price: 28.00),
          OrderItem(name: 'Grilled Chicken', quantity: 2, price: 28.00),
        ],
        totalAmount: 112.00,
      ),
      RestaurantOrder(
        id: 'Order 003',
        status: OrderStatus.ready,
        locationLabel: 'Take way',
        locationValue: null,
        typeLabel: 'Online Order',
        typeValue: null,
        time: '3:34',
        serverName: 'John doe',
        workTime: '12:34',
        workTimeProgress: 1.0,
        items: const [
          OrderItem(name: 'Grilled Chicken', quantity: 2, price: 28.00),
          OrderItem(name: 'Margherita pizza', quantity: 2, price: 28.00),
        ],
        totalAmount: 112.00,
      ),
      RestaurantOrder(
        id: 'Order 01',
        status: OrderStatus.pending,
        locationLabel: 'Table',
        locationValue: '08',
        typeLabel: 'Guests',
        typeValue: '08',
        time: '2:34',
        serverName: 'John doe',
        workTime: '12:34',
        workTimeProgress: 0.65,
        items: const [
          OrderItem(name: 'Kaiser Salad', quantity: 2, price: 28.00),
          OrderItem(name: 'Grilled Chicken', quantity: 2, price: 28.00),
        ],
        totalAmount: 112.00,
      ),
    ];
  }
}
