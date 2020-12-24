package br.ufsc.ine5410;

import org.apache.commons.lang3.ObjectUtils;

import javax.annotation.Nonnull;
import java.util.HashMap;
import java.util.LinkedList;
import java.util.Map;
import java.util.concurrent.Semaphore;
import java.util.concurrent.locks.Lock;
import java.util.concurrent.locks.ReentrantLock;

public class MessageBroker {
    // DICA: Crie um Map<String, XXXX> que mapeia do edereço do receptor para sua
    // caixa postal, onde mensagens enviadas serão enfileiradas e de onde ele
    // retirará mensagens com receive()


    /**!
     * each string(address) maps to:
     *                 - a LinkedList of messages
     *                 - a Lock to access the list
     *                 - a semaphore to tell the threads when new messages
     *                      are there for the taking (via receive())
     * */
    Map<String, LinkedList<Message>> caixaPostal = new HashMap<>();         // map String -> Messages
    Map<String, ReentrantLock> locks = new HashMap<>();                     // map String -> Lock
    Map<String, Semaphore> semaphoreSend = new HashMap<>();                    // map String -> Semaphore
    Map<String, Semaphore> semaphoreReceive = new HashMap<>();                    // map String -> Semaphore


    public void send(@Nonnull Message message) {
        // Envia uma mensagem o mais rápido possível (não bloqueia)
        // throw new UnsupportedOperationException(); // me remova quando implementar o método
        String receptor = message.getReceiver();
        if (!this.caixaPostal.containsKey(message.getReceiver())) {
            String address = message.getReceiver();
            LinkedList<Message> list = new LinkedList<>();
            this.caixaPostal.put(address, list);
            ReentrantLock l = new ReentrantLock();
            locks.put(address, l);
            Semaphore s = new Semaphore(0);
            this.semaphoreSend.put(address, s);
            this.semaphoreReceive.put(address, s);
        }
        try {
            locks.get(receptor).lock();  // lock no lock receptor
            caixaPostal.get(receptor).add(message);  // put message in list
            semaphoreReceive.get(receptor).release();  // notify there is something in buffer
        } finally {
            locks.get(receptor).unlock();  // unlock on lock receptor
        }
    }

    public @Nonnull Message sendAndReceive(@Nonnull Message message) throws InterruptedException {
        // Envia uma mensagem e espera sua resposta (Message.waitForReply())
        // throw new UnsupportedOperationException(); // me remova quando implementar o método
        String receptor = message.getReceiver();
        if (!this.caixaPostal.containsKey(message.getReceiver())) {
            String address = message.getReceiver();
            LinkedList<Message> list = new LinkedList<>();
            this.caixaPostal.put(address, list);
            ReentrantLock l = new ReentrantLock();
            locks.put(address, l);
            Semaphore s = new Semaphore(0);
            this.semaphoreSend.put(address, s);
            this.semaphoreReceive.put(address, s);
        }
        try {
            locks.get(receptor).lock();  // lock no lock receptor
            caixaPostal.get(receptor).add(message);  // put message in list
            semaphoreReceive.get(receptor).release();  // notify there is something in buffer
            //System.out.println("enviou e deu release no semaforo");
        } finally {
            locks.get(receptor).unlock();  // unlock on lock receptor
            return message.waitForReply();
        }
    }

    public @Nonnull Message receive(@Nonnull String receiverAddress) {
        // Espera uma mensagem enviada para o endereço dado e a retorna
        //throw new UnsupportedOperationException(); // me remova quando implementar o método
        Message m = null;
        if (!this.caixaPostal.containsKey(receiverAddress)) {
            String address = receiverAddress;
            LinkedList<Message> list = new LinkedList<>();
            this.caixaPostal.put(address, list);
            ReentrantLock l = new ReentrantLock();
            locks.put(address, l);
            Semaphore s = new Semaphore(0);
            this.semaphoreSend.put(address, s);
            this.semaphoreReceive.put(address, s);
        }
        try {
            //System.out.println("semaforo em receive");
            semaphoreReceive.get(receiverAddress).acquire();  // espero entrar mensagem
            //System.out.println("depois do sem em receive");
            locks.get(receiverAddress).lock();
            m = caixaPostal.get(receiverAddress).removeFirst();
        } catch (InterruptedException e) {
            e.printStackTrace();
        } finally {
            locks.get(receiverAddress).unlock();
        }
        return m;
    }
}

// message list is buffer sem.acquire() to receive, sem.release() when receiving
