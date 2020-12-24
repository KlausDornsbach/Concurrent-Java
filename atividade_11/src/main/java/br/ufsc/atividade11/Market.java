package br.ufsc.atividade11;

import javax.annotation.Nonnull;
import javax.management.monitor.Monitor;
import java.util.HashMap;
import java.util.Map;
//import java.util.concurrent.Semaphore;
import java.util.concurrent.locks.Condition;
import java.util.concurrent.locks.Lock;
import java.util.concurrent.locks.ReadWriteLock;
import java.util.concurrent.locks.ReentrantReadWriteLock;

public class Market {
    private Map<Product, Double> prices = new HashMap<>();
    private Map<Product, ReadWriteLock> locks = new HashMap<>();
    private Map<Product, Monitor> monitors = new HashMap<>();
    private Map<Product, Condition> conditions = new HashMap<>();
    private Map<Product, Integer> produtosCirculando = new HashMap<>();
    //private Map<Product, Semaphore> tentaEscrever = new HashMap<>();
    //private Map<Product, Semaphore> tentaPegar = new HashMap<>();

    public Market() {
        for (Product product : Product.values()) {
            prices.put(product, 1.99);
            produtosCirculando.put(product, 0);
            ReadWriteLock l = new ReentrantReadWriteLock();
            Condition canTake = l.writeLock().newCondition();
            locks.put(product, l);
            conditions.put(product, canTake);
        }
    }  // put default price 1.99

    public void setPrice(@Nonnull Product product, double value) {
        locks.get(product).writeLock().lock();
        prices.put(product, value);  // coloco valor
        conditions.get(product).signalAll();  // fala pra todas threads em waitOffer que mudou o preco
        locks.get(product).writeLock().unlock();
    }

    public double take(@Nonnull Product product) {
        locks.get(product).readLock().lock();
        return prices.get(product);
    }

    public void putBack(@Nonnull Product product) {
        locks.get(product).readLock().unlock();
    }

    public double waitForOffer(@Nonnull Product product,
                               double maximumValue) throws InterruptedException {
        double val;
        try {
            locks.get(product).writeLock().lock();
            boolean a = false;
            while (prices.get(product) > maximumValue) {
                conditions.get(product).await();
            }
            val = take(product);  // pego o produto e saio do
        } finally {
            locks.get(product).writeLock().unlock();
        }
        return val;
    }

    public double pay(@Nonnull Product product) {
        double val = prices.get(product);
        locks.get(product).readLock().unlock();
        return val;
    }
}
