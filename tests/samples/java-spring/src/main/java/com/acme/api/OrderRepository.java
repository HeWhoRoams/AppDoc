package com.acme.api;

import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.CrudRepository;

public interface OrderRepository extends CrudRepository<Object, Long> {

    @Query(value = "select o.id from order_items o "
            + "where o.qty > ?1", nativeQuery = true)
    java.util.List<Object> bigOrders(int qty);

    @Query("delete from OrderAudit a where a.id = ?1")
    void purge(long id);
}
