package wgm

import grails.validation.ValidationException
import static org.springframework.http.HttpStatus.*

class EstoqueDistribuidoraController {

    EstoqueDistribuidoraService estoqueDistribuidoraService

    static allowedMethods = [save: "POST", update: "PUT", delete: "DELETE"]

    def index(Integer max) {
        params.max = Math.min(max ?: 10, 100)
        respond estoqueDistribuidoraService.list(params), model:[estoqueDistribuidoraCount: estoqueDistribuidoraService.count()]
    }

    def show(Long id) {
        respond estoqueDistribuidoraService.get(id)
    }

    def create() {
        respond new EstoqueDistribuidora(params)
    }

    def save(EstoqueDistribuidora estoqueDistribuidora) {
        if (estoqueDistribuidora == null) {
            notFound()
            return
        }

        try {
            estoqueDistribuidoraService.save(estoqueDistribuidora)
        } catch (ValidationException e) {
            respond estoqueDistribuidora.errors, view:'create'
            return
        }

        request.withFormat {
            form multipartForm {
                flash.message = message(code: 'default.created.message', args: [message(code: 'estoqueDistribuidora.label', default: 'EstoqueDistribuidora'), estoqueDistribuidora.id])
                redirect estoqueDistribuidora
            }
            '*' { respond estoqueDistribuidora, [status: CREATED] }
        }
    }

    def edit(Long id) {
        respond estoqueDistribuidoraService.get(id)
    }

    def update(EstoqueDistribuidora estoqueDistribuidora) {
        if (estoqueDistribuidora == null) {
            notFound()
            return
        }

        try {
            estoqueDistribuidoraService.save(estoqueDistribuidora)
        } catch (ValidationException e) {
            respond estoqueDistribuidora.errors, view:'edit'
            return
        }

        request.withFormat {
            form multipartForm {
                flash.message = message(code: 'default.updated.message', args: [message(code: 'estoqueDistribuidora.label', default: 'EstoqueDistribuidora'), estoqueDistribuidora.id])
                redirect estoqueDistribuidora
            }
            '*'{ respond estoqueDistribuidora, [status: OK] }
        }
    }

    def delete(Long id) {
        if (id == null) {
            notFound()
            return
        }

        estoqueDistribuidoraService.delete(id)

        request.withFormat {
            form multipartForm {
                flash.message = message(code: 'default.deleted.message', args: [message(code: 'estoqueDistribuidora.label', default: 'EstoqueDistribuidora'), id])
                redirect action:"index", method:"GET"
            }
            '*'{ render status: NO_CONTENT }
        }
    }

    protected void notFound() {
        request.withFormat {
            form multipartForm {
                flash.message = message(code: 'default.not.found.message', args: [message(code: 'estoqueDistribuidora.label', default: 'EstoqueDistribuidora'), params.id])
                redirect action: "index", method: "GET"
            }
            '*'{ render status: NOT_FOUND }
        }
    }
}
