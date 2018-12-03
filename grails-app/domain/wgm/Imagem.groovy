package wgm

class Imagem {

    Long id
	byte[] img

    Produto produto

    static constraints = {
        img nullable: false
    }

    static mapping = {
        version false
    }
}
