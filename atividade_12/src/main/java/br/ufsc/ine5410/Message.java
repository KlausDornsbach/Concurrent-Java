package br.ufsc.ine5410;

import com.google.common.base.Preconditions;

import javax.annotation.Nonnull;
import javax.annotation.Nullable;
import java.util.Objects;
import java.util.concurrent.Semaphore;

public class Message {
    private @Nonnull String sender;
    private @Nonnull String receiver;
    private @Nullable String payload;

    private @Nullable Message reply = null;
    Semaphore sem;

    public Message(@Nonnull String sender, @Nonnull String receiver,
                   @Nullable String payload) {
        this.sender = sender;
        this.receiver = receiver;
        this.payload = payload;  // mensagem
        sem = new Semaphore(0);
    }

    public @Nonnull String getSender() {
        return sender;
    }
    public @Nonnull String getReceiver() {
        return receiver;
    }
    public @Nullable String getPayload() {
        return payload;
    }

    public @Nonnull Message waitForReply() throws InterruptedException {
        // Esse método só está funcionando se waitForReply() for chamado após
        // reply(). Isso é ruim. Faça esse método funcionar em qualquer escalonamento
        //System.out.println("esperei");
        sem.acquire();
        //System.out.println("peguei");
        assert reply != null;
        return reply;
    }

    public void reply(@Nonnull Message message) {
        Preconditions.checkState(reply == null, "Cannot reply() a message twice!");
        //System.out.println("liberei");
        reply = message;
        sem.release();
        //System.out.println("deu release");
    }

    @Override
    public String toString() {
        return String.format("Message(%s -> %s :: %s)", getSender(), getReceiver(), getPayload());
    }

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (o == null || getClass() != o.getClass()) return false;
        Message message = (Message) o;
        return getSender().equals(message.getSender()) &&
                getReceiver().equals(message.getReceiver()) &&
                Objects.equals(getPayload(), message.getPayload()) &&
                Objects.equals(reply, message.reply);
    }

    @Override
    public int hashCode() {
        return Objects.hash(getSender(), getReceiver(), getPayload(), reply);
    }
}

// associar strings a message brokers
