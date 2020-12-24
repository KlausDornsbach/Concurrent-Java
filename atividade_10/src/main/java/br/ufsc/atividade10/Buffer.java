package br.ufsc.atividade10;

import javax.annotation.Nonnull;
import java.util.Iterator;
import java.util.LinkedList;
import java.util.List;

import static br.ufsc.atividade10.Piece.Type.*;

public class Buffer {
    private final int maxSize;
    public LinkedList<Piece> pieces = new LinkedList<>();

    public Buffer() {
        this(10);
    }
    public Buffer(int maxSize) {
        this.maxSize = maxSize;
    }

    public synchronized void add(Piece piece) throws InterruptedException {
        if (pieces.size() <= maxSize) {  // checks if buffer is full
            if (canPutPiece(piece)) {
                pieces.add(piece);
                notify();
            } else {
                wait();
                add(piece);
            }
        } else {
            wait();
            add(piece);
        }
    }

    public synchronized void takeOXO(@Nonnull List<Piece> xList,
                                     @Nonnull List<Piece> oList) throws InterruptedException {

        Iterator<Piece> iter = pieces.iterator();  // define list iterator
        int contO = 0;  // define counter
        int contX = 0;  // define counter
        int contX2 = 0;
        int contO2 = 0;
        Piece o1 = new Piece(0, X);
        Piece o2 = new Piece(0, X);
        Piece x1 = new Piece(0, O);  // auxiliary variables

        boolean xOk = false, oOk = false;
        while (iter.hasNext()) {
            if (iter.next().getType() == X) {
                contX++;
            } else {
                contO++;
            }
        }
        if (contO >= 2 && contX >= 1) {
            //Iterator<Piece> iter2 = pieces.iterator();  // define list iterator
            int contador = 0;
            while (contador <= pieces.size() && !(oOk && xOk)) {
                if (contX2 == 0 && pieces.get(contador).getType() == X) {
                    x1 = pieces.get(contador);
                    contX2++;
                    contador++;
                    xOk = true;
                }
                if (contO2 == 1 && pieces.get(contador).getType() == O) {
                    o2 = pieces.get(contador);
                    contO2++;
                    contador++;
                    oOk = true;
                }
                if (contO2 == 0 && pieces.get(contador).getType() == O) {
                    o1 = pieces.get(contador);
                    contador++;
                    contO2++;
                } else {
                    contador++;
                }
            }
            pieces.remove(x1);
            pieces.remove(o1);
            pieces.remove(o2);
            xList.add(x1);
            oList.add(o1);
            oList.add(o2);
            notify();
        } else {
            wait();
            takeOXO(xList, oList);
        }
    }

    public boolean canPutPiece(Piece p) {  // boolean if printer can add piece to buf
        Iterator<Piece> iter = pieces.iterator();  // define list iterator
        int cont = 0;  // define counter
        while (iter.hasNext()) {
            Piece aux = iter.next();
            if (aux.getType() == p.getType()) {
                cont++;
            }
        }
        if(p.getType() == X && cont == maxSize - 2) {
            return false;
        }
        if(p.getType() == O && cont == maxSize - 1) {
            return false;
        }
        return true;
    }
}
