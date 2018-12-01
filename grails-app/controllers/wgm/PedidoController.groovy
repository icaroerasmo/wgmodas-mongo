package wgm

import grails.validation.ValidationException
import static org.springframework.http.HttpStatus.*

class PedidoController {

    PedidoService pedidoService

    static allowedMethods = [save: "POST", update: "PUT", delete: "DELETE"]

    def index(Integer max) {
        params.max = Math.min(max ?: 10, 100)
        respond pedidoService.list(params), model:[pedidoCount: pedidoService.count()]
    }

    def show(Long id) {
        respond pedidoService.get(id)
    }

    def create() {
        respond new Pedido(params)
    }

    def save(Pedido pedido) {
        if (pedido == null) {
            notFound()
            return
        }

        try {
            pedidoService.save(pedido)
        } catch (ValidationException e) {
            respond pedido.errors, view:'create'
            return
        }

        request.withFormat {
            form multipartForm {
                flash.message = message(code: 'default.created.message', args: [message(code: 'pedido.label', default: 'Pedido'), pedido.id])
                redirect pedido
            }
            '*' { respond pedido, [status: CREATED] }
        }
    }

    def edit(Long id) {
        respond pedidoService.get(id)
    }

    def update(Pedido pedido) {
        if (pedido == null) {
            notFound()
            return
        }

        try {
            pedidoService.save(pedido)
        } catch (ValidationException e) {
            respond pedido.errors, view:'edit'
            return
        }

        request.withFormat {
            form multipartForm {
                flash.message = message(code: 'default.updated.message', args: [message(code: 'pedido.label', default: 'Pedido'), pedido.id])
                redirect pedido
            }
            '*'{ respond pedido, [status: OK] }
        }
    }

    def delete(Long id) {
        if (id == null) {
            notFound()
            return
        }

        pedidoService.delete(id)

        request.withFormat {
            form multipartForm {
                flash.message = message(code: 'default.deleted.message', args: [message(code: 'pedido.label', default: 'Pedido'), id])
                redirect action:"index", method:"GET"
            }
            '*'{ render status: NO_CONTENT }
        }
    }

    protected void notFound() {
        request.withFormat {
            form multipartForm {
                flash.message = message(code: 'default.not.found.message', args: [message(code: 'pedido.label', default: 'Pedido'), params.id])
                redirect action: "index", method: "GET"
            }
            '*'{ render status: NOT_FOUND }
        }
    }
}
