package wgm

import grails.validation.ValidationException
import static org.springframework.http.HttpStatus.*

class CobrancaVendedoraController {

    CobrancaVendedoraService cobrancaVendedoraService

    static allowedMethods = [save: "POST", update: "PUT", delete: "DELETE"]

    def index(Integer max) {
        params.max = Math.min(max ?: 10, 100)
        respond cobrancaVendedoraService.list(params), model:[cobrancaVendedoraCount: cobrancaVendedoraService.count()]
    }

    def show(Long id) {
        respond cobrancaVendedoraService.get(id)
    }

    def create() {
        respond new CobrancaVendedora(params)
    }

    def save(CobrancaVendedora cobrancaVendedora) {
        if (cobrancaVendedora == null) {
            notFound()
            return
        }

        try {
            cobrancaVendedoraService.save(cobrancaVendedora)
        } catch (ValidationException e) {
            respond cobrancaVendedora.errors, view:'create'
            return
        }

        request.withFormat {
            form multipartForm {
                flash.message = message(code: 'default.created.message', args: [message(code: 'cobrancaVendedora.label', default: 'CobrancaVendedora'), cobrancaVendedora.id])
                redirect cobrancaVendedora
            }
            '*' { respond cobrancaVendedora, [status: CREATED] }
        }
    }

    def edit(Long id) {
        respond cobrancaVendedoraService.get(id)
    }

    def update(CobrancaVendedora cobrancaVendedora) {
        if (cobrancaVendedora == null) {
            notFound()
            return
        }

        try {
            cobrancaVendedoraService.save(cobrancaVendedora)
        } catch (ValidationException e) {
            respond cobrancaVendedora.errors, view:'edit'
            return
        }

        request.withFormat {
            form multipartForm {
                flash.message = message(code: 'default.updated.message', args: [message(code: 'cobrancaVendedora.label', default: 'CobrancaVendedora'), cobrancaVendedora.id])
                redirect cobrancaVendedora
            }
            '*'{ respond cobrancaVendedora, [status: OK] }
        }
    }

    def delete(Long id) {
        if (id == null) {
            notFound()
            return
        }

        cobrancaVendedoraService.delete(id)

        request.withFormat {
            form multipartForm {
                flash.message = message(code: 'default.deleted.message', args: [message(code: 'cobrancaVendedora.label', default: 'CobrancaVendedora'), id])
                redirect action:"index", method:"GET"
            }
            '*'{ render status: NO_CONTENT }
        }
    }

    protected void notFound() {
        request.withFormat {
            form multipartForm {
                flash.message = message(code: 'default.not.found.message', args: [message(code: 'cobrancaVendedora.label', default: 'CobrancaVendedora'), params.id])
                redirect action: "index", method: "GET"
            }
            '*'{ render status: NOT_FOUND }
        }
    }
}
