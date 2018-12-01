package wgm

class Fabrica {

    Long id
	String nome
	String endereco
	String telefone

    static constraints = {
        nome blank: false, nullable: false
        endereco blank: false, nullable: false
        telefone blank: false, nullable: false
    }
}
