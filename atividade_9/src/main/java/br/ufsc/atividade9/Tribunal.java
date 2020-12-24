package br.ufsc.atividade9;

import javax.annotation.Nonnull;
import java.util.concurrent.*;

public class Tribunal implements AutoCloseable {
    ThreadPoolExecutor.DiscardPolicy discard = new ThreadPoolExecutor.DiscardPolicy();

    public ArrayBlockingQueue<Runnable> queue;  // declaro fila
    protected final ExecutorService executor;
    int tamFila;

    public Tribunal(int  nJuizes, int tamFila) {
        this.tamFila = tamFila;
        this.queue = new ArrayBlockingQueue<>(tamFila);  // crio a fila
        this.executor = new ThreadPoolExecutor(nJuizes, nJuizes, 0, TimeUnit.SECONDS, this.queue, discard);
    }

    public boolean julgar(@Nonnull final Processo processo) throws TribunalSobrecarregadoException {
        final boolean[] aux = new boolean[1];
        Future<boolean[]> futuro;

        class MyCall implements Callable<boolean[]> {
            @Override
            public boolean[] call() throws Exception {
                aux[0] = checkGuilty(processo);
                return aux;
            }
        }
        MyCall myC = new MyCall();
        if (queue.size() == tamFila) {
            aux[0] = false;
        } else {
            futuro = executor.submit(myC);
            try {
                aux[0] = futuro.get()[0];
            } catch (InterruptedException e) {
                e.printStackTrace();
            } catch (ExecutionException e) {
                e.printStackTrace();
            }
        }
        return aux[0];
    }

    protected boolean checkGuilty(Processo processo) {
        try {
            Thread.sleep((long) (50 + 50*Math.random()));
        } catch (InterruptedException ignored) {}
        return processo.getId() % 7 == 0;
    }

    @Override
    public void close() throws Exception {
        executor.shutdown();
        while(!executor.isTerminated()){  // busy wait maroto

        }
    }
}
