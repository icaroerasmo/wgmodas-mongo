package wgm

import grails.validation.ValidationException
import static org.springframework.http.HttpStatus.*

class ImagemController {

    ImagemService imagemService

    static allowedMethods = [save: "POST", update: "PUT", delete: "DELETE"]

    def index(Integer max) {
        params.max = Math.min(max ?: 10, 100)
        respond imagemService.list(params), model:[imagemCount: imagemService.count()]
    }

    def show(Long id) {
        respond imagemService.get(id)
    }

    def create() {
        respond new Imagem(params)
    }

    def save(Imagem imagem) {
        if (imagem == null) {
            notFound()
            return
        }

        try {
            imagemService.save(imagem)
        } catch (ValidationException e) {
            respond imagem.errors, view:'create'
            return
        }

        request.withFormat {
            form multipartForm {
                flash.message = message(code: 'default.created.message', args: [message(code: 'imagem.label', default: 'Imagem'), imagem.id])
                redirect imagem
            }
            '*' { respond imagem, [status: CREATED] }
        }
    }

    def edit(Long id) {
        respond imagemService.get(id)
    }

    def update(Imagem imagem) {
        if (imagem == null) {
            notFound()
            return
        }

        try {
            imagemService.save(imagem)
        } catch (ValidationException e) {
            respond imagem.errors, view:'edit'
            return
        }

        request.withFormat {
            form multipartForm {
                flash.message = message(code: 'default.updated.message', args: [message(code: 'imagem.label', default: 'Imagem'), imagem.id])
                redirect imagem
            }
            '*'{ respond imagem, [status: OK] }
        }
    }

    def delete(Long id) {
        if (id == null) {
            notFound()
            return
        }

        imagemService.delete(id)

        request.withFormat {
            form multipartForm {
                flash.message = message(code: 'default.deleted.message', args: [message(code: 'imagem.label', default: 'Imagem'), id])
                redirect action:"index", method:"GET"
            }
            '*'{ render status: NO_CONTENT }
        }
    }

    protected void notFound() {
        request.withFormat {
            form multipartForm {
                flash.message = message(code: 'default.not.found.message', args: [message(code: 'imagem.label', default: 'Imagem'), params.id])
                redirect action: "index", method: "GET"
            }
            '*'{ render status: NOT_FOUND }
        }
    }
}
